#!/usr/bin/python3
"""Plays GNOME Calls towards the VoLTE daemon: one outgoing call, records
what the network sends (PCMA), hangs up.  usage: callprobe.py NUMBER SECONDS"""
import os, random, select, socket, struct, sys, time, wave

NUM, SECS = sys.argv[1], float(sys.argv[2])
GW = ('127.0.0.1', 5070)


def rnd(n=10):
    return ''.join(random.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(n))


def alaw_to_lin(a):
    a ^= 0x55
    t = (a & 0x0F) << 4
    seg = (a & 0x70) >> 4
    if seg == 0:
        t += 8
    elif seg == 1:
        t += 0x108
    else:
        t += 0x108
        t <<= seg - 1
    return t if a & 0x80 else -t


sip = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sip.bind(('127.0.0.1', 0))
rtp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
rtp.bind(('127.0.0.1', 0))
sp, rp = sip.getsockname()[1], rtp.getsockname()[1]
cid, tag = rnd(12) + '@probe', rnd(6)


def req(method, cseq, to_tag=None, body='', br=None):
    h = ['%s sip:%s@127.0.0.1:5070 SIP/2.0' % (method, NUM),
         'Via: SIP/2.0/UDP 127.0.0.1:%d;branch=%s;rport' % (sp, br or 'z9hG4bK' + rnd()),
         'Max-Forwards: 70', 'From: <sip:probe@127.0.0.1>;tag=%s' % tag,
         'To: <sip:%s@127.0.0.1>%s' % (NUM, ';tag=' + to_tag if to_tag else ''),
         'Call-ID: %s' % cid, 'CSeq: %d %s' % (cseq, method), 'Contact: <sip:probe@127.0.0.1:%d>' % sp]
    if body:
        h.append('Content-Type: application/sdp')
    h.append('Content-Length: %d' % len(body))
    return ('\r\n'.join(h) + '\r\n\r\n' + body).encode()


def log(*a):
    print(time.strftime('%H:%M:%S'), *a, flush=True)


sdp = ('v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\ns=-\r\nc=IN IP4 127.0.0.1\r\nt=0 0\r\n'
       'm=audio %d RTP/AVP 8 0\r\na=rtpmap:8 PCMA/8000\r\na=rtpmap:0 PCMU/8000\r\na=sendrecv\r\n' % rp)
inv_branch = 'z9hG4bK' + rnd()
sip.sendto(req('INVITE', 1, body=sdp, br=inv_branch), GW)
log('INVITE', NUM)
to_tag = None
gw_rtp = None
t0 = time.time()
answered = False
while time.time() - t0 < 40:
    r, _, _ = select.select([sip], [], [], 1)
    if not r:
        continue
    data, _ = sip.recvfrom(65535)
    txt = data.decode(errors='replace')
    first = txt.split('\r\n')[0]
    log('<<<', first)
    if not first.startswith('SIP/2.0'):
        continue
    code = int(first.split()[1])
    for l in txt.split('\r\n'):
        if l.lower().startswith('to:') and ';tag=' in l:
            to_tag = l.split(';tag=')[1].split(';')[0].strip()
        if l.startswith('m=audio'):
            gw_rtp = int(l.split()[1])
    if code >= 200:
        if code < 300:
            sip.sendto(req('ACK', 1, to_tag), GW)
            answered = True
        else:
            # ACK for non-2xx: same branch
            sip.sendto(req('ACK', 1, to_tag, br=inv_branch), GW)
        break
if not answered:
    log('call not answered')
    sys.exit(1)

log('answered, recording %d s (gateway RTP port %s)' % (SECS, gw_rtp))
frames = bytearray()
seq, ts, ssrc = random.randint(0, 65535), random.randint(0, 1 << 30), random.randint(0, 1 << 30)
t0 = time.time()
next_tx = t0
rx_pkts = 0
while time.time() - t0 < SECS:
    now = time.time()
    if gw_rtp and now >= next_tx:
        pkt = struct.pack('!BBHII', 0x80, 8, seq & 0xFFFF, ts & 0xFFFFFFFF, ssrc) + b'\xd5' * 160
        rtp.sendto(pkt, ('127.0.0.1', gw_rtp))
        seq += 1
        ts += 160
        next_tx += 0.02
    r, _, _ = select.select([rtp, sip], [], [], max(0, next_tx - time.time()))
    for s in r:
        data, _ = s.recvfrom(65535)
        if s is rtp and len(data) > 12:
            rx_pkts += 1
            frames += data[12:]
        elif s is sip:
            log('<<<', data.decode(errors='replace').split('\r\n')[0])
            if data.startswith(b'BYE'):
                txt = data.decode(errors='replace')
                via = [l for l in txt.split('\r\n') if l.lower().startswith('via:')][0]
                hs = [l for l in txt.split('\r\n') if l.split(':')[0].lower() in ('from', 'to', 'call-id', 'cseq')]
                sip.sendto(('SIP/2.0 200 OK\r\n%s\r\n%s\r\nContent-Length: 0\r\n\r\n' % (via, '\r\n'.join(hs))).encode(), GW)
                t0 = -1e9
sip.sendto(req('BYE', 2, to_tag), GW)
log('BYE sent; rx RTP packets', rx_pkts)
end = time.time() + 5
while time.time() < end:
    r, _, _ = select.select([sip], [], [], 1)
    if r:
        log('<<<', sip.recvfrom(65535)[0].decode(errors='replace').split('\r\n')[0])
        break
pcm = [alaw_to_lin(b) for b in frames]
w = wave.open('/tmp/probe-rx.wav', 'wb')
w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
w.writeframes(struct.pack('<%dh' % len(pcm), *pcm))
w.close()
out = []
for k in range(0, len(pcm), 8000):
    x = pcm[k:k + 8000]
    out.append('%d' % int((sum(v * v for v in x) / max(1, len(x))) ** 0.5))
log('received audio RMS per second:', ' '.join(out))
