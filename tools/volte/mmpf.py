"""LG modem media engine (MMPF on the CP) over the LG VSS IMS QMI service.

Wire format (from libimsmmpf.lge.so MMPF_CP_IF): QMI service 703 message
0x060C carries one 300-byte blob (TLV 0x01) both as request (AP->CP) and as
indication (CP->AP).  Each blob = 32-byte header + up to 220 data bytes:
  u32 type, u32 last, u32 len, u32 offset, u32 hdrsize(32), u32 session,
  u32 seq, u32 0
AP->CP types: 0 create session, 1 destroy session, 2 set property,
  3 request, 4 get state, 5 clear all, 7 create bridge, 8 destroy bridge,
  9 data to bridge.
CP->AP types: 0 response(u32 request, u32 result), 1 notify(u32 code),
  2 CP ip addr, 3 create bridge, 4 destroy bridge, 5 socket data,
  6 L3 data, 9 rx packet counts, 11 RTT data, 16 socket IF id.
"""
import socket
import struct

import qmiqrtr

SVC = 703
MSG = 0x060C
BLOB = 300
CHUNK = 220

# _eMMPFCPMsgType (AP->CP)
CREATE, DESTROY, SETPROP, REQUEST, GETSTATE, CLEARALL = 0, 1, 2, 3, 4, 5
# property types
P_TXSOURCE, P_CODEC, P_TRANSPORT, P_NETWORK, P_DISPLAY, P_DEBUG = range(6)
# wire sizes (12-byte property header + data), from MMPF_CP_IF::setProperty
P_SIZE = {P_TXSOURCE: 284, P_CODEC: 416, P_TRANSPORT: 204, P_NETWORK: 280,
          P_DISPLAY: 52, P_DEBUG: 276}
# requests (_eMMPFRequest)
R_START, R_STOP, R_PAUSE, R_RESUME, R_SEND_DTMF = 2, 3, 4, 5, 21
R_PREPARE_STOP, R_RESET = 25, 28
# modes
TX, RX = 0, 1
# codecs (AudioMediaSession::UpdateProperty)
AMR, AMR_WB, EVS = 3, 4, 8
IND_NAMES = {0: 'response', 1: 'notify', 2: 'ipaddr', 3: 'create-bridge',
             4: 'destroy-bridge', 5: 'socket-data', 6: 'l3-data', 9: 'rx-count',
             11: 'rtt', 16: 'socket-if'}


def _u32s(*v):
    return struct.pack('<%dI' % len(v), *[x & 0xffffffff for x in v])


def _cstr(s, n):
    b = s.encode()[:n - 1]
    return b + bytes(n - len(b))


def network_prop(mode, src_ip, dst_ip, rtp_local, rtp_remote, apn='ims',
                 profile=-1, tos=184, socket_pos=1, rtcp=True, rtcp_remote=None):
    """MMPF_PROPERTY_NETWORK (AudioAdaptor::SetMMPFNetworkProperty).
    Offsets below are data offsets (struct offset - 16).
    socket_pos 1 = "cp": the modem owns the RTP socket (LG MegaFon config)"""
    d = bytearray(P_SIZE[P_NETWORK] - 12)
    struct.pack_into('<III', d, 0, 2, 0, 0)          # LRTP, src v6?, dst v6?
    d[12:12 + 46] = _cstr(src_ip, 46)
    d[58:58 + 46] = _cstr(dst_ip, 46)
    # RTP port info {u32 0, local, remote, u8 tos}, then RTCP port info
    struct.pack_into('<IIIB', d, 104, 0, rtp_local, rtp_remote, tos & 0xff)
    if rtcp:
        struct.pack_into('<IIIB', d, 120, 0, rtp_local + 1, rtcp_remote or rtp_remote + 1, tos & 0xff)
    struct.pack_into('<i', d, 136, profile)          # PDP profile (LTE)
    d[140:140 + 64] = _cstr(apn, 64)
    struct.pack_into('<iI', d, 204, -1, socket_pos)  # PDP profile (CDMA), eSocketPos
    # 212.. media dump, RTCP-XR flags, ignore old SSRC, ePDG, network id,
    # slot id, MDM: all 0
    return _u32s(P_NETWORK, mode, 0) + bytes(d)


def codec_prop(mode, codec, modeset, scr=True, jitter=(4, 4, 9), option=2):
    """MMPF_PROPERTY_CODEC (AudioAdaptor::SetMMPFAudioCodecProperty).
    jitter = (init, min, max) in frames."""
    d = bytearray(P_SIZE[P_CODEC] - 12)
    struct.pack_into('<IIII', d, 0, codec, option, modeset, 0 if scr else 1)
    struct.pack_into('<III', d, 28, jitter[0], jitter[1], jitter[2])
    return _u32s(P_CODEC, mode, 0) + bytes(d)


def transport_prop(mode, pt_local, pt_remote, rate, ptime=20, octet_align=True,
                   dtmf_pt=0, dtmf_rate=0, timeout=0):
    """MMPF_PROPERTY_TRANSPORT (AudioAdaptor::SetMMPFRtpProperty)."""
    d = bytearray(P_SIZE[P_TRANSPORT] - 12)
    struct.pack_into('<IIIIII', d, 0, 2, pt_local, pt_remote, rate, ptime,
                     0 if octet_align else 1)
    if dtmf_pt:
        struct.pack_into('<II', d, 24, dtmf_pt, 1)
        struct.pack_into('<III', d, 32, 10, 2, 2)    # duration, retransmit, interval
        struct.pack_into('<I', d, 48, dtmf_rate)
    struct.pack_into('<II', d, 60, 1 if timeout else 0, timeout)
    return _u32s(P_TRANSPORT, mode, 0) + bytes(d)


def txsource_prop():
    """MMPF_PROPERTY_TXSOURCE: LIVE (microphone via the modem voice path)."""
    d = bytearray(P_SIZE[P_TXSOURCE] - 12)
    struct.pack_into('<I', d, 0, 1)
    return _u32s(P_TXSOURCE, TX, 0) + bytes(d)


def request(req, mode):
    return _u32s(req, mode, 0) + bytes(12)


def dtmf_request(signal):
    """R_SEND_DTMF on the TX stream: the tone string at byte 12, 140 bytes in
    all (MMPF_CP_IF::sendDTMF; the engine picks the event length itself)"""
    return _u32s(R_SEND_DTMF, TX, 0) + _cstr(signal, 128)


class Mmpf:
    def __init__(self, log=print):
        self.qmi = qmiqrtr.Client(SVC, 'lge-ims')
        self.seq = 0
        self.log = log
        self.parts = {}

    def send(self, typ, session, data=b''):
        """split into 220-byte chunks like MMPF_CP_IF_send_msg"""
        off = 0
        while True:
            chunk = data[off:off + CHUNK]
            last = 1 if off + len(chunk) >= len(data) else 0
            self.seq += 1
            hdr = _u32s(typ, last, len(chunk), off, 32, session, self.seq, 0)
            blob = hdr + chunk
            blob += bytes(BLOB - len(blob))
            res, err, _ = self.qmi.request(MSG, qmiqrtr.tlv(1, blob), timeout=5)
            if res:
                raise RuntimeError('mmpf send type %d: QMI error %d' % (typ, err))
            off += len(chunk)
            if last:
                return

    def indications(self, timeout=0.0):
        """returns [(type, session, data)] of complete CP indications"""
        out = []
        for mid, tl in self.qmi.poll_indications(timeout):
            if mid != MSG or 1 not in tl:
                continue
            b = tl[1]
            typ, last, ln, off, hs, sess, seq, _ = struct.unpack_from('<8I', b)
            buf = self.parts.setdefault((typ, sess), bytearray())
            if off == 0:
                del buf[:]
            buf += b[hs:hs + ln]
            if last:
                out.append((typ, sess, bytes(buf)))
                del self.parts[(typ, sess)]
        return out

    def close(self):
        self.qmi.close()


def describe(typ, sess, data):
    name = IND_NAMES.get(typ, str(typ))
    if typ == 0 and len(data) >= 8:
        return '%s s%d request %d result %d' % (name, sess, *struct.unpack_from('<II', data))
    if typ == 1 and len(data) >= 4:
        return '%s s%d code %d %s' % (name, sess, struct.unpack_from('<I', data)[0], data[4:16].hex())
    if typ == 2:
        return '%s s%d %r' % (name, sess, data[4:50].split(b'\0')[0])
    return '%s s%d %d bytes %s' % (name, sess, len(data), data[:32].hex())
