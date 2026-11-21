#!/usr/bin/python3
"""SIM access over QMI UIM (QRTR): logical channels + APDUs.
usage: uimtool.py read-isim AID_HEX | read-usim AID_HEX"""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qmiqrtr import Client, tlv

SLOT = 1


class Uim:
    def __init__(self):
        self.c = Client(11, 'UIM')

    def open(self, aid):
        res, err, b = self.c.request(0x42, tlv(0x01, bytes([SLOT])) +
                                     tlv(0x10, bytes([len(aid)]) + aid))
        if res:
            raise RuntimeError('open channel: error %d %s' % (err, b.get(0x11, b'').hex()))
        return b[0x10][0]

    def close(self, ch):
        self.c.request(0x3F, tlv(0x01, bytes([SLOT])) + tlv(0x11, bytes([ch])) +
                       tlv(0x13, b'\x01'))

    def apdu(self, ch, data):
        cla = (ch if ch < 4 else 0x40 | (ch - 4))
        data = bytes([data[0] | cla]) + data[1:]
        res, err, b = self.c.request(0x3B, tlv(0x01, bytes([SLOT])) +
                                     tlv(0x02, struct.pack('<H', len(data)) + data) +
                                     tlv(0x10, bytes([ch])))
        if res:
            raise RuntimeError('apdu: error %d' % err)
        r = b[0x10]
        ln = struct.unpack_from('<H', r)[0]
        r = r[2:2 + ln]
        return r[:-2], (r[-2] << 8) | r[-1]

    def get_response(self, ch, sw):
        if sw >> 8 == 0x61:
            return self.apdu(ch, bytes([0x00, 0xC0, 0, 0, sw & 0xFF]))
        return b'', sw

    def select(self, ch, fid):
        r, sw = self.apdu(ch, bytes([0x00, 0xA4, 0x00, 0x04, 2]) + struct.pack('>H', fid) + b'\x00')
        if sw >> 8 == 0x61:
            r, sw = self.get_response(ch, sw)
        return r, sw

    def read_binary(self, ch, fid):
        _, sw = self.select(ch, fid)
        if sw != 0x9000:
            return None, sw
        return self.apdu(ch, bytes([0x00, 0xB0, 0, 0, 0]))

    def read_record(self, ch, fid, rec=1):
        _, sw = self.select(ch, fid)
        if sw != 0x9000:
            return None, sw
        return self.apdu(ch, bytes([0x00, 0xB2, rec, 0x04, 0]))


def nai(v):
    if v and v[0] == 0x80:
        return v[2:2 + v[1]].decode(errors='replace')
    return v.hex() if v else None


def mask(s):
    if not s:
        return s
    if '@' in s:
        u, d = s.split('@', 1)
        return '%s***(%d)@%s' % (u[:4], len(u), d)
    return s[:4] + '***(%d)' % len(s)


if __name__ == '__main__':
    u = Uim()
    cmd, aid = sys.argv[1], bytes.fromhex(sys.argv[2].replace(':', ''))
    ch = u.open(aid)
    print('logical channel', ch)
    try:
        if cmd == 'read-isim':
            for name, fid, rec in (('IMPI', 0x6F02, 0), ('DOMAIN', 0x6F03, 0),
                                   ('IMPU1', 0x6F04, 1), ('IMPU2', 0x6F04, 2), ('PCSCF', 0x6F09, 1)):
                r, sw = (u.read_record(ch, fid, rec) if rec else u.read_binary(ch, fid))
                val = nai(r) if r is not None else None
                print('%-6s sw %04x %s' % (name, sw, val if name == 'DOMAIN' else mask(val)))
    finally:
        u.close(ch)
