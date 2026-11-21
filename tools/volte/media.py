"""Per call media: AMR-WB/AMR RTP (IMS network) <-> the user's PulseAudio,
with GStreamer.

GNOME Calls only does the signalling of a VoLTE call: its own SIP media
pipeline (rtpbin + pulsesink/pulsesrc, PCMA) stalls on this PulseAudio
setup (sink starved, "clock skew", source read errors), so the audio of the
call is played and recorded here. Calls gets an SDP pointing at a local port
nobody reads; GNOME Calls still switches callaudiod to call mode (earpiece,
speaker button), and the streams here follow the default sink/source.
"""
import os
import pwd
import subprocess

import gi
gi.require_version('Gst', '1.0')
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib, Gst

Gst.init(None)

PROPS = 'props,media.role=phone,application.name=VoLTE,filter.suppress=echo-cancel'


def udp_socket(ip, port=0):
    s = Gio.Socket.new(Gio.SocketFamily.IPV4, Gio.SocketType.DATAGRAM, Gio.SocketProtocol.UDP)
    s.bind(Gio.InetSocketAddress.new_from_string(ip, port), True)
    return s


def sock_port(s):
    return s.get_local_address().get_port()


def session_user():
    """uid of the logged in user (owner of gnome-calls, not the greeter)"""
    out = subprocess.run(['pgrep', '-x', 'gnome-calls'], capture_output=True, text=True).stdout.split()
    names = [p.pw_name for p in pwd.getpwall()]
    greeter = pwd.getpwnam('greetd').pw_uid if 'greetd' in names else -1
    for pid in out:
        try:
            uid = os.stat('/proc/' + pid).st_uid
        except OSError:
            continue
        if uid not in (0, greeter):
            return uid
    return None


def parec(uid, rate):
    """microphone capture: GStreamer's pulsesrc delivers nothing from this
    PulseAudio (huge source latency), parec works"""
    pw = pwd.getpwuid(uid)
    env = {'XDG_RUNTIME_DIR': '/run/user/%d' % uid, 'HOME': pw.pw_dir, 'PATH': '/usr/bin:/bin'}
    return subprocess.Popen(['parec', '--raw', '--rate=%d' % rate, '--channels=1', '--format=s16le',
                             '--latency-msec=20', '--client-name=VoLTE', '--property=media.role=phone',
                             '--property=filter.suppress=echo-cancel'],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env,
                            user=uid, group=pw.pw_gid)


def pacat(uid, rate):
    """playback: pulsesink loses the stream when callaudiod switches the card
    profile under it (call mode); pacat follows the move"""
    pw = pwd.getpwuid(uid)
    env = {'XDG_RUNTIME_DIR': '/run/user/%d' % uid, 'HOME': pw.pw_dir, 'PATH': '/usr/bin:/bin'}
    return subprocess.Popen(['pacat', '--playback', '--raw', '--rate=%d' % rate, '--channels=1', '--format=s16le',
                             '--latency-msec=100', '--client-name=VoLTE', '--property=media.role=phone',
                             '--property=filter.suppress=echo-cancel'],
                            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            env=env, user=uid, group=pw.pw_gid)


# the card's native rates: PulseAudio's own resampler (speex-float-1) makes
# 8 kHz speech sound metallic, so resample here at the best quality
SPK_RATE = 48000
MIC_RATE = 44100


def spk_sink(fd, rate=SPK_RATE):
    return ('audioconvert ! audioresample quality=10 ! audio/x-raw,format=S16LE,rate=%d,channels=1 ! '
            'fdsink name=spkfd fd=%d sync=false async=false' % (rate, fd))


def mic_src(fd, rate):
    return ('fdsrc name=micfd fd=%d blocksize=%d do-timestamp=true ! '
            'rawaudioparse use-sink-caps=false format=pcm pcm-format=s16le sample-rate=%d num-channels=1 ! '
            'audioconvert' % (fd, rate * 2 // 50, rate))


def session_pulse():
    """PulseAudio server of the logged in user (owner of gnome-calls, not
    the greeter); sets PULSE_SERVER / PULSE_COOKIE for this process"""
    out = subprocess.run(['pgrep', '-x', 'gnome-calls'], capture_output=True, text=True).stdout.split()
    greeter = pwd.getpwnam('greetd').pw_uid if 'greetd' in [p.pw_name for p in pwd.getpwall()] else -1
    for pid in out:
        try:
            uid = os.stat('/proc/' + pid).st_uid
        except OSError:
            continue
        if uid in (0, greeter):
            continue
        sock = '/run/user/%d/pulse/native' % uid
        cookie = os.path.join(pwd.getpwuid(uid).pw_dir, '.config/pulse/cookie')
        if os.path.exists(sock):
            os.environ['PULSE_SERVER'] = 'unix:' + sock
            if os.path.exists(cookie):
                os.environ['PULSE_COOKIE'] = cookie
            return sock
    return None


class Relay:
    def __init__(self, net_ip, log):
        self.log = log
        self.net_ip = net_ip
        self.net_sock = None
        for p in range(40000, 40400, 2):
            try:
                self.net_sock = udp_socket(net_ip, p)
                break
            except GLib.Error:
                continue
        # the port GNOME Calls is told about; its RTP is not used
        self.loc_sock = udp_socket('127.0.0.1', 0)
        self.net_port = sock_port(self.net_sock)
        self.loc_port = sock_port(self.loc_sock)
        self.pipes = []
        self.count = {}
        self.levels = {}
        self.stats_src = None
        self.mic = None
        self.spk = []

    def _launch(self, desc, socks):
        p = Gst.parse_launch(desc)
        for name, sock in socks.items():
            el = p.get_by_name(name)
            el.set_property('socket', sock)
            el.set_property('close-socket', False)
        for name in ('spk', 'spk2'):
            el = p.get_by_name(name)
            if el is not None:
                el.set_property('stream-properties', Gst.Structure.new_from_string(PROPS))
        bus = p.get_bus()
        bus.add_signal_watch()
        bus.connect('message::error', self._err)
        bus.connect('message::element', self._level)
        p.set_state(Gst.State.PLAYING)
        self.pipes.append(p)
        return p

    def _count(self, p, name, pad, key):
        self.count[key] = 0
        p.get_by_name(name).get_static_pad(pad).add_probe(Gst.PadProbeType.BUFFER, self._probe, key)

    def start(self, remote_ip, remote_port, pt, codec, calls_port=None, mode=2, calls_ip=None, **kw):
        """codec 'AMR-WB' or 'AMR' (octet aligned)"""
        server = session_pulse()
        wb = codec == 'AMR-WB'
        rate = 16000 if wb else 8000
        caps_net = ('application/x-rtp,media=audio,clock-rate=%d,encoding-name=%s,encoding-params=(string)1,'
                    'octet-align=(string)1,payload=%d' % (rate, codec, pt))
        dec = 'amrwbdec' if wb else 'amrnbdec'
        enc = ('voamrwbenc band-mode=%d' % mode) if wb else ('amrnbenc band-mode=%d' % min(mode + 5, 7))
        uid = session_user()
        # playback at the codec rate: resampling it here (quality 10, 48 kHz)
        # sounded worse than PulseAudio's resampler
        self.spk = [pacat(uid, rate)]
        down = ('udpsrc name=net caps="%s" ! rtpjitterbuffer name=jb latency=120 do-lost=true ! rtpamrdepay ! %s ! '
                'audioconvert ! level name=lvl_down interval=5000000000 ! %s'
                % (caps_net, dec, spk_sink(self.spk[0].stdin.fileno(), rate)))
        self.mic = parec(uid, MIC_RATE)
        up = ('%s ! audioresample quality=10 ! audio/x-raw,rate=%d,channels=1 ! '
              'level name=lvl_mic interval=5000000000 ! %s ! rtpamrpay pt=%d ! '
              'udpsink name=out host=%s port=%d sync=false async=false'
              % (mic_src(self.mic.stdout.fileno(), MIC_RATE), rate, enc, pt, remote_ip, remote_port))
        p = self._launch(down, {'net': self.net_sock})
        self._count(p, 'net', 'src', 'net>')
        p = self._launch(up, {'out': self.net_sock})
        self._count(p, 'out', 'sink', '>net')
        self.log('media: %s pt %d mode %d, network %s:%d <-> :%d, audio via %s'
                 % (codec, pt, mode, remote_ip, remote_port, self.net_port, server))
        self.stats_src = GLib.timeout_add_seconds(5, self._stats)

    def start_echo(self, calls_port=None, calls_ip=None):
        """local audio test: the microphone comes back 0.5 s later, with a
        tick every second"""
        server = session_pulse()
        uid = session_user()
        self.mic = parec(uid, MIC_RATE)
        self.spk = [pacat(uid, SPK_RATE), pacat(uid, SPK_RATE)]
        desc = ('%s ! level name=lvl_mic interval=1000000000 ! '
                'queue max-size-time=0 max-size-buffers=0 max-size-bytes=0 min-threshold-time=500000000 ! %s'
                % (mic_src(self.mic.stdout.fileno(), MIC_RATE), spk_sink(self.spk[0].stdin.fileno())))
        self._launch(desc, {})
        self._launch('audiotestsrc wave=ticks volume=0.4 is-live=true ! audio/x-raw,rate=48000,channels=1 ! %s'
                     % spk_sink(self.spk[1].stdin.fileno()), {})
        self.log('echo test via %s' % server)

    def _probe(self, pad, info, key):
        self.count[key] += 1
        return Gst.PadProbeReturn.OK

    def _level(self, bus, msg):
        s = msg.get_structure()
        if s and s.get_name() == 'level':
            rms = s.get_value('rms')
            self.log('media level %s %.1f dB' % (msg.src.get_name(), rms[0] if rms else -999))

    def _stats(self):
        if self.count:
            extra = ''
            for p in self.pipes:
                jb = p.get_by_name('jb')
                if jb is not None:
                    st = jb.get_property('stats')
                    extra = ' | jitterbuffer pushed %s lost %s late %s jitter %.1f ms' % (
                        st.get_value('num-pushed'), st.get_value('num-lost'), st.get_value('num-late'),
                        (st.get_value('avg-jitter') or 0) / 1e6)
            self.log('media packets: ' + ' '.join('%s %d' % kv for kv in self.count.items()) + extra)
        return bool(self.pipes)

    def _err(self, bus, msg):
        err, dbg = msg.parse_error()
        self.log('media error: %s %s' % (err, (dbg or '')[:200]))

    def stop(self):
        if self.pipes:
            self._stats()
        for p in self.pipes:
            p.set_state(Gst.State.NULL)
        self.pipes = []
        for proc in [self.mic] + self.spk:
            if not proc:
                continue
            proc.terminate()
            try:
                proc.wait(2)
            except subprocess.TimeoutExpired:
                proc.kill()
        self.mic = None
        self.spk = []
        if self.stats_src:
            GLib.source_remove(self.stats_src)
            self.stats_src = None
        for s in (self.net_sock, self.loc_sock):
            try:
                s.close()
            except GLib.Error:
                pass
