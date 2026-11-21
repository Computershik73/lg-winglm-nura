#!/usr/bin/python3
"""Prototype: bring up a PDN over the downstream IPA (rmnet_ipa0) the way
Android's netmgrd does, keep it for a while, then tear it down.
usage: wdata.py APN MUX SECONDS [--dpm] [--ipv6] [--profile N] [--ping HOST]"""
import ctypes, fcntl, os, socket, struct, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qmiqrtr import Client, tlv

RMNET_IOCTL_EXTENDED = 0x89FD
ADD_MUX_CHANNEL, SET_EGRESS, SET_INGRESS, GET_EP_PAIR = 0x05, 0x06, 0x07, 0x10
EG_MAP, EG_MUX = 1 << 1, 1 << 3
IN_MAP, IN_DEAGG, IN_DEMUX, IN_CSUM, IN_AGG = 1 << 1, 1 << 2, 1 << 3, 1 << 4, 1 << 5
V5 = '--v5' in sys.argv
EP_EMBEDDED, EP_IFACE = 4, 1
STATE = '/run/winglm-ipa-ready'

args = sys.argv[1:]
apn, mux, secs = args[0], int(args[1]), float(args[2])
opt = set(a for a in args[3:] if a.startswith('--'))
def optval(name, default=None):
    return args[args.index(name) + 1] if name in args else default


LOGF = open('/var/tmp/wdata.log', 'a')


def log(*a):
    line = ' '.join([time.strftime('%H:%M:%S')] + [str(x) for x in a])
    print(line, flush=True)
    LOGF.write(line + '\n')
    LOGF.flush()
    os.fsync(LOGF.fileno())


log('==== start', ' '.join(sys.argv[1:]), 'uptime', open('/proc/uptime').read().split()[0])


def ext_ioctl(sub, payload=b''):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    cbuf = ctypes.create_string_buffer(struct.pack('<I', sub) + payload.ljust(32, b'\0'), 36)
    ifr = struct.pack('16sQ', b'rmnet_ipa0', ctypes.addressof(cbuf)) + bytes(16)
    fcntl.ioctl(s.fileno(), RMNET_IOCTL_EXTENDED, ifr)
    s.close()
    return cbuf.raw


def sh(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    log('$', cmd, '->', r.returncode, (r.stdout + r.stderr).strip()[:300])
    return r


cons, prod = struct.unpack_from('<II', ext_ioctl(GET_EP_PAIR), 4)
log('ep pair: consumer %d producer %d' % (cons, prod))

if not os.path.exists(STATE):
    sh('ip link set rmnet_ipa0 up')
    ext_ioctl(SET_EGRESS, struct.pack('<I', EG_MAP | EG_MUX))
    log('egress format set')
    if V5:  # like netmgrd on lito: DL checksum offload (QMAPv5 hdr) + aggregation
        ext_ioctl(SET_INGRESS, struct.pack('<III', IN_MAP | IN_DEAGG | IN_DEMUX | IN_CSUM | IN_AGG, 31668, 31))
    else:
        ext_ioctl(SET_INGRESS, struct.pack('<III', IN_MAP | IN_DEAGG | IN_DEMUX, 0, 0))
    log('ingress format set')
    open(STATE, 'w').close()

ifname = 'rmnet_data%d' % (mux - 1)
if not os.path.exists('/sys/class/net/' + ifname):
    sh('ip link add link rmnet_ipa0 name %s type rmnet mux_id %d ingress-deaggregation %s%s' % (ifname, mux, optval("--deagg", "on"), ' ingress-mapv5-checksum on' if V5 else ''))
log('before ADD_MUX_CHANNEL')
ext_ioctl(ADD_MUX_CHANNEL, struct.pack('<I16s', mux, ifname.encode()))
log('mux channel %d -> %s added' % (mux, ifname))

ep = struct.pack('<II', EP_EMBEDDED, EP_IFACE)
dpm = None
if '--dpm' in opt:
    dpm = Client(47, 'DPM')
    # like ModemManager: hardware data port only, rx = IPA ep the AP
    # transmits on (APPS_WAN_PROD), tx = IPA ep the AP receives on
    hw = struct.pack('<B', 1) + ep + struct.pack('<II', cons, prod)
    log('DPM open port: sending')
    r = dpm.request(0x20, tlv(0x11, hw), timeout=15)
    log('DPM open port: result %d error %d' % r[:2])

wda = Client(26, 'WDA')
req = (tlv(0x11, struct.pack('<I', 2)) + tlv(0x12, struct.pack('<I', 5)) +
       tlv(0x13, struct.pack('<I', 9 if V5 else 5)) + tlv(0x15, struct.pack('<I', 31 if V5 else 1)) +
       tlv(0x16, struct.pack('<I', 31668 if V5 else 2048)) + tlv(0x17, ep))
res, err, body = wda.request(0x20, req)
log('WDA set data format: result %d error %d tlvs %s' % (res, err, {k: v.hex() for k, v in body.items() if k != 2}))

wds = Client(1, 'WDS')
res, err, _ = wds.request(0xA2, tlv(0x10, ep) + tlv(0x11, struct.pack('<B', mux)))
log('WDS bind mux %d: result %d error %d' % (mux, res, err))
fam = 6 if '--ipv6' in opt else 4
res, err, _ = wds.request(0x4D, tlv(0x01, struct.pack('<B', fam)))
log('WDS set ip family %d: result %d error %d' % (fam, res, err))

sn = tlv(0x19, struct.pack('<B', fam))
if apn != '-':
    sn += tlv(0x14, apn.encode())
if optval('--profile'):
    sn += tlv(0x31, struct.pack('<B', int(optval('--profile'))))
res, err, body = wds.request(0x20, sn, timeout=60)
log('WDS start network: result %d error %d tlvs %s' % (res, err, {k: v.hex() for k, v in body.items() if k != 2}))
if res != 0:
    sys.exit(1)
handle = struct.unpack('<I', body[1])[0]

res, err, s = wds.request(0x2D, tlv(0x10, struct.pack('<I', 0xFFFFFFFF & ~(1 << 5))))
log('WDS settings: result %d error %d' % (res, err))
def v4(b):
    return socket.inet_ntoa(struct.pack('>I', struct.unpack('<I', b)[0]))
info = {}
for t, v in sorted(s.items()):
    if t in (0x15, 0x16, 0x1E, 0x20, 0x21) and len(v) == 4:
        info[t] = v4(v)
    elif t == 0x25:
        info[t] = socket.inet_ntop(socket.AF_INET6, v[:16]) + '/%d' % v[16]
    elif t in (0x26,):
        info[t] = socket.inet_ntop(socket.AF_INET6, v[:16]) + '/%d' % v[16]
    elif t in (0x27, 0x28) and len(v) == 16:
        info[t] = socket.inet_ntop(socket.AF_INET6, v)
    elif t == 0x23 and v:
        info[t] = [v4(v[1 + 4 * i:5 + 4 * i]) for i in range(v[0])]
    elif t == 0x2E and v:
        info[t] = [socket.inet_ntop(socket.AF_INET6, v[1 + 16 * i:17 + 16 * i]) for i in range(v[0])]
    elif t == 0x29:
        info[t] = struct.unpack('<I', v)[0]
    elif t != 2:
        info[t] = v.hex() if len(v) < 40 else v[:40].hex() + '...'
for t, v in info.items():
    log('  tlv %#04x: %s' % (t, v))

sh('ip link set %s up' % ifname)
if fam == 4 and 0x1E in info:
    sh('ip addr add %s/32 dev %s' % (info[0x1E], ifname))
    if 0x29 in info:
        sh('ip link set %s mtu %d' % (ifname, info[0x29]))
    host = optval('--ping', '1.1.1.1')
    sh('ip route add %s/32 dev %s' % (host, ifname))
    if '--txonly' in opt:
        # one UDP datagram to a black-hole address: exercises TX only
        log('sending one UDP datagram to %s via %s' % (host, ifname))
        os.sync()
        time.sleep(1)
        u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        u.setsockopt(socket.SOL_SOCKET, 25, ifname.encode())
        u.sendto(b'x' * 32, (host, 9))
        u.close()
        time.sleep(3)
        log('still alive after TX')
    elif '--noping' not in opt:
        os.sync()
        sh("ping -c %s -W 3 -I %s %s" % (optval("--count", "4"), ifname, host))
    sh('ip route del %s/32 dev %s' % (host, ifname))
    if optval('--hook'):
        sh('sh %s' % optval('--hook'))
elif fam == 6 and 0x25 in info:
    sh('ip -6 addr add %s dev %s' % (info[0x25].split('/')[0] + '/64', ifname))
    host = optval('--ping', '2606:4700:4700::1111')
    sh('ip -6 route add %s/128 dev %s' % (host, ifname))
    sh('ping -6 -c 4 -W 3 -I %s %s' % (ifname, host))
    sh('ip -6 route del %s/128 dev %s' % (host, ifname))
sh('cat /sys/class/net/%s/statistics/rx_packets /sys/class/net/%s/statistics/tx_packets' % (ifname, ifname))

t0 = time.time()
while time.time() - t0 < secs:
    for mid, b in wds.poll_indications(1.0):
        log('WDS ind %#x %s' % (mid, {k: v.hex() for k, v in b.items()}))

res, err, _ = wds.request(0x21, tlv(0x01, struct.pack('<I', handle)))
log('WDS stop network: result %d error %d' % (res, err))
sh('ip addr flush dev %s' % ifname)
sh('ip link set %s down' % ifname)
