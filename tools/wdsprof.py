#!/usr/bin/python3
"""WDS 3GPP profiles: list (raw TLVs), create an IMS profile, delete.
usage: wdsprof.py list | create-ims | delete N"""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qmiqrtr import Client, tlv

wds = Client(1, 'WDS')
cmd = sys.argv[1]
if cmd == 'list':
    res, err, b = wds.request(0x2A, tlv(0x10, b'\0'))
    d = b.get(1, b'\0')
    n = d[0]; off = 1; idx = []
    for _ in range(n):
        t, i, ln = d[off], d[off + 1], d[off + 2]
        name = d[off + 3:off + 3 + ln].decode(errors='replace')
        off += 3 + ln
        idx.append(i)
        print('profile', i, repr(name))
    for i in idx:
        res, err, s = wds.request(0x2B, tlv(0x01, struct.pack('<BB', 0, i)))
        print('-- profile %d (res %d err %d)' % (i, res, err))
        for t in sorted(s):
            if t == 2:
                continue
            v = s[t]
            txt = v.decode(errors='replace') if t in (0x10, 0x14, 0x1B) else v.hex()
            print('   %#04x [%d] %s' % (t, len(v), txt))
elif cmd == 'create-ims':
    req = (tlv(0x01, b'\0') +                       # 3GPP
           tlv(0x10, b'winglm-ims') +                 # profile name
           tlv(0x11, b'\0') +                         # PDP type IPv4
           tlv(0x14, b'ims') +                        # APN
           tlv(0x1F, b'\x01') +                       # P-CSCF address via PCO
           tlv(0x22, b'\x01'))                        # IM CN flag
    res, err, b = wds.request(0x27, req)
    print('create: res %d err %d' % (res, err), {k: v.hex() for k, v in b.items() if k != 2})
elif cmd == 'delete':
    res, err, b = wds.request(0x29, tlv(0x01, struct.pack('<BB', 0, int(sys.argv[2]))))
    print('delete: res %d err %d' % (res, err))
