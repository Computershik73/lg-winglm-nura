"""VoLTE media in the modem, like LG's Android stack does it.

The modem runs LG's MMPF media engine: it opens its own RTP/RTCP sockets on
the IMS PDN (packet filters keep that traffic away from the AP), does the
AMR/AMR-WB codec, jitter buffer and RTCP, and feeds the Qualcomm voice
services (VS -> CVD), i.e. the same DSP voice path and calibration as a CS
call.  The AP only has to configure the session over the LG VSS IMS QMI
service (mmpf.py) and start the VoiceMMode1 voice session (hw:0,2, like
q6voiced does for CS calls) once the call audio route is set.
"""
import ctypes
import os
import re
import socket
import struct

from gi.repository import GLib

import mmpf

FORCE_AP = '/etc/winglm-volte/ap-media'     # touch to use AP (GStreamer) media
PORTS = list(range(50010, 50062, 2))        # LG MegaFon config: 50010-50060
JITTER = (4, 4, 9)                          # init, min, max frames (LG MegaFon)
TOS = 184

_engine = None
_port_i = 0


def enabled():
    return not os.path.exists(FORCE_AP)


def engine(log):
    """shared QMI client; clears stale CP sessions on first use"""
    global _engine
    if _engine is None:
        e = mmpf.Mmpf(log=log)
        e.send(mmpf.CLEARALL, 0)
        _engine = e
        log('modem media: MMPF client ready (QMI %s)' % (e.qmi.addr,))
    return _engine


def drop_engine():
    global _engine
    if _engine is not None:
        try:
            _engine.close()
        except Exception:
            pass
    _engine = None


def next_port():
    global _port_i
    p = PORTS[_port_i % len(PORTS)]
    _port_i += 1
    return p


def modeset(name, fmtp):
    m = re.search(r'mode-set=([\d,]+)', fmtp or '')
    top = 8 if name == 'AMR-WB' else 7
    if m:
        bits = 0
        for x in m.group(1).split(','):
            if x.isdigit() and int(x) <= top:
                bits |= 1 << int(x)
        if bits:
            return bits
    # LG default_rtp_modeset 0,1,2 (12.65k) for AMR-WB; all modes for AMR
    return 0x7 if name == 'AMR-WB' else 0xFF


class VoicePcm:
    """hostless VoiceMMode1 PCMs: preparing both directions starts the voice
    session on the DSP (voc_start_voice_call); needs the call route first,
    so retry until hw_params succeeds"""
    DEV = b'hw:0,2'
    _quiet = None

    def __init__(self, log):
        self.log = log
        self.lib = ctypes.CDLL('libasound.so.2')
        if VoicePcm._quiet is None:
            # hw_params fails until callaudiod has set the route: keep
            # ALSA's error prints out of the daemon log
            fn = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int,
                                  ctypes.c_char_p)
            VoicePcm._quiet = fn(lambda *a: None)
            self.lib.snd_lib_error_set_handler(VoicePcm._quiet)
        self.pcms = []
        self.src = None
        self.tries = 0

    def open(self):
        self.tries = 0
        self.src = GLib.timeout_add(500, self._try)

    def _try(self):
        self.tries += 1
        self._close_pcms()
        ok = True
        for stream in (0, 1):
            p = ctypes.c_void_p()
            r = self.lib.snd_pcm_open(ctypes.byref(p), self.DEV, stream, 0)
            if r < 0:
                ok = False
                break
            self.pcms.append(p)
            r = self.lib.snd_pcm_set_params(p, 2, 3, 1, 8000, 0, 500000)
            if r < 0:
                ok = False
                break
        if ok:
            for p in self.pcms:
                if self.lib.snd_pcm_prepare(p) < 0:
                    ok = False
        if ok:
            self.log('modem media: VoiceMMode1 voice session started (try %d)' % self.tries)
            self.src = None
            return False
        self._close_pcms()
        if self.tries >= 40:
            self.log('modem media: could not start VoiceMMode1 (%d tries)' % self.tries)
            self.src = None
            return False
        return True

    def _close_pcms(self):
        for p in self.pcms:
            self.lib.snd_pcm_close(p)
        self.pcms = []

    def close(self):
        if self.src:
            GLib.source_remove(self.src)
            self.src = None
        self._close_pcms()


class ModemRelay:
    modem = True

    def __init__(self, net_ip, log, profile):
        self.log = log
        self.net_ip = net_ip
        self.profile = profile if profile is not None else -1
        self.net_port = next_port()
        # the port GNOME Calls is told about; its RTP is not used
        self.loc_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.loc_sock.bind(('127.0.0.1', 0))
        self.loc_port = self.loc_sock.getsockname()[1]
        self.session = 0
        self.started = False
        self.watch = None
        self.pcm = None
        self.e = None

    def start(self, remote_ip, remote_port, pt, codec, calls_port=None, mode=2, calls_ip=None,
              fmtp='', oa=True, dtmf_pt=None, rtcp_port=None, **kw):
        e = self.e = engine(self.log)
        wb = codec == 'AMR-WB'
        rate = 16000 if wb else 8000
        bits = modeset(codec, fmtp)
        rtcp_remote = rtcp_port or remote_port + 1
        msgs = []
        for m in (mmpf.RX, mmpf.TX):
            msgs.append(mmpf.network_prop(m, self.net_ip, remote_ip, self.net_port, remote_port,
                                          profile=self.profile, tos=TOS, rtcp_remote=rtcp_remote))
            msgs.append(mmpf.transport_prop(m, pt, pt, rate, octet_align=oa,
                                            dtmf_pt=dtmf_pt or 0, dtmf_rate=rate if dtmf_pt else 0))
            msgs.append(mmpf.codec_prop(m, mmpf.AMR_WB if wb else mmpf.AMR, bits, jitter=JITTER))
        msgs.append(mmpf.txsource_prop())
        try:
            e.send(mmpf.DESTROY, self.session)      # leftovers of a crashed call
            e.send(mmpf.CREATE, self.session)
            for b in msgs:
                e.send(mmpf.SETPROP, self.session, b)
            e.send(mmpf.REQUEST, self.session, mmpf.request(mmpf.R_START, mmpf.RX))
            e.send(mmpf.REQUEST, self.session, mmpf.request(mmpf.R_START, mmpf.TX))
        except Exception:
            drop_engine()
            raise
        self.started = True
        self.watch = GLib.timeout_add(500, self._poll)
        self.pcm = VoicePcm(self.log)
        self.pcm.open()
        self.log('modem media: %s pt %d %s mode-set 0x%x dtmf %s, %s:%d <-> %s:%d'
                 % (codec, pt, 'octet-aligned' if oa else 'bandwidth-efficient', bits, dtmf_pt,
                    self.net_ip, self.net_port, remote_ip, remote_port))

    def _poll(self):
        if not self.e:
            return False
        try:
            for typ, sess, data in self.e.indications(0):
                if typ == 9 and len(data) >= 12:
                    rtp, sr, rr = struct.unpack_from('<III', data)
                    self.log('modem media: received RTP %d, RTCP SR %d RR %d' % (rtp, sr, rr))
                else:
                    self.log('modem media: ' + mmpf.describe(typ, sess, data))
        except Exception as ex:
            self.log('modem media: indication error %s' % ex)
        return self.started

    def stop(self):
        if self.pcm:
            self.pcm.close()
            self.pcm = None
        if self.started and self.e:
            self.started = False
            try:
                for m in (mmpf.TX, mmpf.RX):
                    self.e.send(mmpf.REQUEST, self.session, mmpf.request(mmpf.R_STOP, m))
                self.e.send(mmpf.DESTROY, self.session)
                self._poll()
            except Exception as ex:
                self.log('modem media: stop failed: %s' % ex)
                drop_engine()
            self.log('modem media stopped')
        if self.watch:
            GLib.source_remove(self.watch)
            self.watch = None
        try:
            self.loc_sock.close()
        except OSError:
            pass
