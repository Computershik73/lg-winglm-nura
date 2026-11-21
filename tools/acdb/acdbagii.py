#!/usr/bin/python3
"""Dump the ADM audproc (AGII) calibration of one device from an ACDB file.
usage: acdbagii.py FILE [DEVICE_ID]"""
import struct, sys
from acdbls import chunks

p = sys.argv[1]
want = int(sys.argv[2]) if len(sys.argv) > 2 else None
d = open(p, 'rb').read()
ch = {cid: (off, ln) for cid, off, ln in chunks(d)}


def chunk(cid):
    off, ln = ch[cid]
    return d[off:off + ln]


lut = chunk('AGIILUT0')
cdft = chunk('AGIICDFT')
cdot = chunk('AGIICDOT')
pool = chunk('DATAPOOL')
n, = struct.unpack_from('<I', lut, 0)
ent = (len(lut) - 4) // n // 4
print('AGIILUT0: %d entries x %d words' % (n, ent))
rows = [struct.unpack_from('<%dI' % ent, lut, 4 + i * ent * 4) for i in range(n)]
devs = sorted(set(r[0] for r in rows))
print('devices:', devs[:80])
for r in rows:
    if want is not None and r[0] != want:
        continue
    dev, rate, app, fo, oo = r[:5]
    nf, = struct.unpack_from('<I', cdft, fo)
    defs = [struct.unpack_from('<III', cdft, fo + 4 + 12 * i) for i in range(nf)]
    no, = struct.unpack_from('<I', cdot, oo)
    offs = struct.unpack_from('<%dI' % no, cdot, oo + 4)
    print('dev %d rate %d app %#x: %d params' % (dev, rate, app, nf))
    for (mid, iid, pid), po in zip(defs, offs):
        ln, = struct.unpack_from('<I', pool, po)
        data = pool[po + 4:po + 4 + ln]
        print('   module %#07x inst %d param %#07x len %4d  %s' % (mid, iid, pid, ln, data[:20].hex(' ')))
