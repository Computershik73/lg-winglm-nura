#!/usr/bin/python3
"""List the chunks of a Qualcomm ACDB (QCMSNDDB) file.
layout: 'QCMSNDDB' + 8 bytes, file type (4) + 4, u32 size, u32 size,
then chunks: 8-byte id, u32 length, data"""
import struct, sys


def chunks(d):
    off = 32
    while off + 12 <= len(d):
        cid = d[off:off + 8]
        ln, = struct.unpack_from('<I', d, off + 8)
        yield cid.decode('latin-1'), off + 12, ln
        off += 12 + ln


if __name__ == '__main__':
    for p in sys.argv[1:]:
        d = open(p, 'rb').read()
        print('== %s: magic %r type %r size %d/%d (file %d)' % (
            p, d[:8], d[16:20], *struct.unpack_from('<II', d, 24), len(d)))
        for cid, off, ln in chunks(d):
            head = d[off:off + min(ln, 24)]
            print('  %-8s @%-8d len %-8d %s' % (cid, off, ln, head.hex(' ')))
