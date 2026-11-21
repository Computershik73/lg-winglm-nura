"""SDP for the two call legs: AMR-WB/AMR towards the IMS network, PCMA
towards GNOME Calls."""
import random
import re
import time


class Sdp:
    def __init__(self, text):
        self.text = text
        self.conn = None
        self.port = None
        self.pts = []
        self.rtpmap = {}      # pt -> (name, rate)
        self.fmtp = {}        # pt -> str
        self.attrs = []       # media level attributes (raw)
        self.direction = 'sendrecv'
        in_audio = False
        for line in text.replace('\r\n', '\n').split('\n'):
            line = line.strip()
            if line.startswith('c=IN IP4 ') or line.startswith('c=IN IP6 '):
                self.conn = line.split()[2]
            elif line.startswith('m='):
                in_audio = line.startswith('m=audio')
                if in_audio:
                    p = line.split()
                    self.port = int(p[1])
                    self.pts = [int(x) for x in p[3:] if x.isdigit()]
            elif line.startswith('a=') and in_audio:
                a = line[2:]
                self.attrs.append(a)
                m = re.match(r'rtpmap:(\d+) ([^/]+)/(\d+)', a)
                if m:
                    self.rtpmap[int(m.group(1))] = (m.group(2), int(m.group(3)))
                m = re.match(r'fmtp:(\d+) (.*)', a)
                if m:
                    self.fmtp[int(m.group(1))] = m.group(2)
                if a in ('sendrecv', 'sendonly', 'recvonly', 'inactive'):
                    self.direction = a

    def codec(self, pt):
        return self.rtpmap.get(pt, ({0: 'PCMU', 8: 'PCMA', 9: 'G722'}.get(pt, '?'), 8000))

    def has_precondition(self):
        return any(a.startswith(('curr:qos', 'des:qos')) for a in self.attrs)

    def mandatory_precondition(self):
        return any(re.match(r'des:qos mandatory', a) for a in self.attrs)

    def pick_amr(self, be_ok=False):
        """best AMR-WB/AMR payload we can handle -> (pt, name, fmtp,
        octet_align) or None.  GStreamer (AP media) does octet-aligned only;
        the modem (be_ok) does both"""
        best = None
        for pt in self.pts:
            name, rate = self.codec(pt)
            if name.upper() not in ('AMR-WB', 'AMR'):
                continue
            f = self.fmtp.get(pt, '')
            oa = 'octet-align=1' in f.replace(' ', '')
            if not oa and not be_ok:
                continue
            score = (2 if name.upper() == 'AMR-WB' else 1) * 10 + (5 if oa else 0)
            if best is None or score > best[0]:
                best = (score, pt, name.upper(), f, oa)
        return best[1:] if best else None

    def rtcp_port(self):
        for a in self.attrs:
            m = re.match(r'rtcp:(\d+)', a)
            if m:
                return int(m.group(1))
        return None

    def dtmf_pt(self, rate):
        for pt in self.pts:
            n, r = self.codec(pt)
            if n.lower() == 'telephone-event' and r == rate:
                return pt
        return None


_sess = random.randint(100000, 999999)


def _origin(ip, ver):
    return 'o=- %d %d IN IP4 %s' % (_sess, ver, ip)


def net_offer(ip, port, ver=1, modem=False):
    """MO offer to the network: AMR-WB and AMR, octet aligned (what
    GStreamer's rtpamr(de)pay supports) and, with modem media, also
    bandwidth efficient like LG's own offer; DTMF events"""
    if modem:
        pts = '116 117 97 98 118 110'
        codecs = ['a=rtpmap:116 AMR-WB/16000/1',
                  'a=fmtp:116 mode-change-capability=2;max-red=0;octet-align=1',
                  'a=rtpmap:117 AMR-WB/16000/1',
                  'a=fmtp:117 mode-change-capability=2;max-red=0',
                  'a=rtpmap:97 AMR/8000/1',
                  'a=fmtp:97 mode-change-capability=2;max-red=0;octet-align=1',
                  'a=rtpmap:98 AMR/8000/1',
                  'a=fmtp:98 mode-change-capability=2;max-red=0']
    else:
        pts = '116 97 118 110'
        codecs = ['a=rtpmap:116 AMR-WB/16000/1',
                  'a=fmtp:116 mode-change-capability=2;max-red=0;octet-align=1',
                  'a=rtpmap:97 AMR/8000/1',
                  'a=fmtp:97 mode-change-capability=2;max-red=0;octet-align=1']
    lines = [
        'v=0', _origin(ip, ver), 's=-', 'c=IN IP4 %s' % ip, 'b=AS:41', 'b=RS:0', 'b=RR:0', 't=0 0',
        'm=audio %d RTP/AVP %s' % (port, pts),
        'b=AS:41'] + codecs + [
        'a=rtpmap:118 telephone-event/16000',
        'a=fmtp:118 0-15',
        'a=rtpmap:110 telephone-event/8000',
        'a=fmtp:110 0-15',
        'a=ptime:20', 'a=maxptime:240', 'a=sendrecv',
    ]
    return '\r\n'.join(lines) + '\r\n'


def net_answer(ip, port, offer, choice, ver=1, precond=None):
    """answer to a network offer with one AMR payload (+DTMF)"""
    pt, name, fmtp, oa = choice
    rate = 16000 if name == 'AMR-WB' else 8000
    dt = offer.dtmf_pt(rate)
    pts = [pt] + ([dt] if dt is not None else [])
    lines = ['v=0', _origin(ip, ver), 's=-', 'c=IN IP4 %s' % ip, 'b=AS:41', 'b=RS:0', 'b=RR:0', 't=0 0',
             'm=audio %d RTP/AVP %s' % (port, ' '.join(str(x) for x in pts)),
             'b=AS:41',
             'a=rtpmap:%d %s/%d/1' % (pt, name, rate)]
    f = fmtp or ''
    if oa and 'octet-align' not in f:
        f = (f + ';' if f else '') + 'octet-align=1'
    if f:
        lines.append('a=fmtp:%d %s' % (pt, f))
    if dt is not None:
        lines += ['a=rtpmap:%d telephone-event/%d' % (dt, rate), 'a=fmtp:%d 0-15' % dt]
    lines += ['a=ptime:20', 'a=maxptime:240']
    if precond:
        lines += precond
    lines.append('a=sendrecv')
    return '\r\n'.join(lines) + '\r\n'


def local_sdp(port, ver=1):
    """towards GNOME Calls: PCMA only"""
    lines = ['v=0', _origin('127.0.0.1', ver), 's=-', 'c=IN IP4 127.0.0.1', 't=0 0',
             'm=audio %d RTP/AVP 8' % port, 'a=rtpmap:8 PCMA/8000', 'a=ptime:20', 'a=sendrecv']
    return '\r\n'.join(lines) + '\r\n'
