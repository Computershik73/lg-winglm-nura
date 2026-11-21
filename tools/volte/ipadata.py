"""LG Wing (SM7250, downstream IPA v4.7): PDN data path over rmnet_ipa0.

Mirrors what Android's netmgrd does on "lito":
  * once per boot: rmnet_ipa0 up, IPA egress (QMAP, mux) / ingress (QMAPv5
    DL checksum header, aggregation) formats, DPM open port (hardware data
    port only), WDA data format (UL QMAP, DL QMAPv5)
  * per PDN: rmnet link (mux id, deaggregation + MAPv5 checksum), IPA mux
    channel, WDS bind mux data port, start network, IP config
"""
import ctypes
import fcntl
import os
import socket
import struct
import subprocess
import time

from qmiqrtr import Client, tlv

RMNET_IOCTL_EXTENDED = 0x89FD
ADD_MUX_CHANNEL, SET_EGRESS, SET_INGRESS, GET_EP_PAIR = 0x05, 0x06, 0x07, 0x10
EG_MAP, EG_MUX = 1 << 1, 1 << 3
IN_MAP, IN_DEAGG, IN_DEMUX, IN_CSUM, IN_AGG = 1 << 1, 1 << 2, 1 << 3, 1 << 4, 1 << 5
EP = struct.pack('<II', 4, 1)          # embedded, interface 1
# shared with ModemManager (downstream IPA patch): formats set this boot
STATE = '/run/rmnet-ipa-data-format'


def run(cmd, check=False):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError('%s: %s' % (cmd, (r.stdout + r.stderr).strip()))
    return r


def ext_ioctl(sub, payload=b''):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    cbuf = ctypes.create_string_buffer(struct.pack('<I', sub) + payload.ljust(32, b'\0'), 36)
    ifr = struct.pack('16sQ', b'rmnet_ipa0', ctypes.addressof(cbuf)) + bytes(16)
    fcntl.ioctl(s.fileno(), RMNET_IOCTL_EXTENDED, ifr)
    s.close()
    return cbuf.raw


class Ipa:
    """process-wide data path state; keep the object alive (DPM client)"""

    def __init__(self, log=print):
        self.log = log
        cons, prod = struct.unpack_from('<II', ext_ioctl(GET_EP_PAIR), 4)
        ifindex = open('/sys/class/net/rmnet_ipa0/ifindex').read().strip()
        done = open(STATE).read().strip() if os.path.exists(STATE) else None
        if done != ifindex:
            log('IPA: setting data formats')
            run('ip link set rmnet_ipa0 up', True)
            ext_ioctl(SET_EGRESS, struct.pack('<I', EG_MAP | EG_MUX))
            ext_ioctl(SET_INGRESS, struct.pack('<III', IN_MAP | IN_DEAGG | IN_DEMUX | IN_CSUM | IN_AGG,
                                               31668, 31))
            with open(STATE, 'w') as f:
                f.write(ifindex)
            log('IPA formats set (ep %d/%d)' % (cons, prod))
        log('IPA: DPM open port')
        self.dpm = Client(47, 'DPM')
        res, err, _ = self.dpm.request(0x20, tlv(0x11, b'\x01' + EP + struct.pack('<II', cons, prod)), timeout=15)
        if res:
            raise RuntimeError('DPM open port: error %d' % err)
        self.wda = Client(26, 'WDA')
        res, err, _ = self.wda.request(0x20, tlv(0x11, struct.pack('<I', 2)) + tlv(0x12, struct.pack('<I', 5)) +
                                       tlv(0x13, struct.pack('<I', 9)) + tlv(0x15, struct.pack('<I', 31)) +
                                       tlv(0x16, struct.pack('<I', 31668)) + tlv(0x17, EP))
        if res:
            raise RuntimeError('WDA set data format: error %d' % err)


def _v4(b):
    return socket.inet_ntoa(struct.pack('>I', struct.unpack('<I', b)[0]))


class Pdn:
    def __init__(self, mux, apn=None, profile=None, family=4, log=print):
        self.mux, self.apn, self.profile, self.family, self.log = mux, apn, profile, family, log
        self.ifname = 'rmnet_data%d' % (mux - 1)
        self.wds = None
        self.handle = None
        self.settings = {}

    def start(self):
        if not os.path.exists('/sys/class/net/' + self.ifname):
            self.log('PDN: creating %s' % self.ifname)
            run('ip link add link rmnet_ipa0 name %s type rmnet mux_id %d ingress-deaggregation on '
                'ingress-mapv5-checksum on' % (self.ifname, self.mux), True)
        self.log('PDN: IPA mux channel %d' % self.mux)
        ext_ioctl(ADD_MUX_CHANNEL, struct.pack('<I16s', self.mux, self.ifname.encode()))
        self.log('PDN: start network')
        self.wds = Client(1, 'WDS')
        res, err, _ = self.wds.request(0xA2, tlv(0x10, EP) + tlv(0x11, bytes([self.mux])))
        if res:
            raise RuntimeError('WDS bind mux: error %d' % err)
        self.wds.request(0x4D, tlv(0x01, bytes([self.family])))
        sn = tlv(0x19, bytes([self.family]))
        if self.apn:
            sn += tlv(0x14, self.apn.encode())
        if self.profile:
            sn += tlv(0x31, bytes([self.profile]))
        res, err, b = self.wds.request(0x20, sn, timeout=60)
        if res:
            raise RuntimeError('start network: error %d %s' % (err, {k: v.hex() for k, v in b.items() if k != 2}))
        self.handle = struct.unpack('<I', b[1])[0]
        res, err, s = self.wds.request(0x2D, tlv(0x10, struct.pack('<I', 0xFFFFFFFF & ~(1 << 5))))
        st = {}
        if 0x1E in s:
            st['ip'] = _v4(s[0x1E])
        if 0x15 in s:
            st['dns'] = [_v4(s[0x15])] + ([_v4(s[0x16])] if 0x16 in s else [])
        if 0x23 in s and s[0x23]:
            st['pcscf'] = [_v4(s[0x23][1 + 4 * i:5 + 4 * i]) for i in range(s[0x23][0])]
        if 0x29 in s:
            st['mtu'] = struct.unpack('<I', s[0x29])[0]
        self.settings = st
        run('ip link set %s up' % self.ifname, True)
        if 'mtu' in st:
            run('ip link set %s mtu %d' % (self.ifname, st['mtu']))
        run('ip addr add %s/32 dev %s' % (st['ip'], self.ifname), True)
        return st

    def route(self, dst):
        run('ip route replace %s/32 dev %s src %s' % (dst, self.ifname, self.settings['ip']), True)

    def stop(self):
        if self.wds and self.handle is not None:
            self.wds.request(0x21, tlv(0x01, struct.pack('<I', self.handle)))
            self.handle = None
        run('ip addr flush dev %s' % self.ifname)
        run('ip link set %s down' % self.ifname)
        if self.wds:
            self.wds.close()
            self.wds = None


def ims_profile(log=print):
    """index of the 3GPP profile for APN "ims" with P-CSCF via PCO and the IM
    CN flag; created on first use (lives in the modem's EFS)"""
    wds = Client(1, 'WDS')
    try:
        res, err, b = wds.request(0x2A, tlv(0x10, b'\0'))
        d = b.get(1, b'\0')
        off = 1
        for _ in range(d[0]):
            idx, ln = d[off + 1], d[off + 2]
            off += 3 + ln
            res, err, st = wds.request(0x2B, tlv(0x01, bytes([0, idx])))
            if st.get(0x14, b'').lower() == b'ims' and st.get(0x1F) == b'\x01' and st.get(0x22) == b'\x01':
                return idx
        res, err, b = wds.request(0x27, tlv(0x01, b'\0') + tlv(0x10, b'winglm-ims') + tlv(0x11, b'\0') +
                                  tlv(0x14, b'ims') + tlv(0x1F, b'\x01') + tlv(0x22, b'\x01'))
        if res:
            raise RuntimeError('create IMS profile: error %d' % err)
        log('created WDS profile %d for the IMS APN' % b[1][1])
        return b[1][1]
    finally:
        wds.close()


def modem_ids():
    """IMEI (DMS get IDs) - internal use only"""
    dms = Client(2, 'DMS')
    res, err, b = dms.request(0x25)
    dms.close()
    return b.get(0x11, b'').decode()


def lte_cell():
    """(plmn, tac, eci) from NAS cell location info"""
    r = run('qmicli -d qrtr://0 --nas-get-cell-location-info')
    plmn = tac = eci = None
    for line in r.stdout.splitlines():
        line = line.strip()
        if line.startswith('PLMN:') and plmn is None:
            plmn = line.split("'")[1]
        elif line.startswith('Tracking Area Code:') and tac is None:
            tac = int(line.split("'")[1])
        elif line.startswith('Global Cell ID:') and eci is None:
            eci = int(line.split("'")[1])
    return plmn, tac, eci
