#!/usr/bin/python3
"""AMR RTP payload format check (octet-aligned vs bandwidth-efficient) from a pcap"""
import collections, struct, sys
d = open(sys.argv[1], 'rb').read()
link, = struct.unpack_from('<I', d, 20)
off = 24
flows = collections.defaultdict(list)
while off + 16 <= len(d):
    ts, tus, incl, orig = struct.unpack_from('<IIII', d, off)
    pkt = d[off + 16:off + 16 + incl]
    off += 16 + incl
    ip = pkt[16:] if link == 113 else (pkt[4:] if link == 0 else pkt)
    if len(ip) < 28 or ip[0] >> 4 != 4 or ip[9] != 17:
        continue
    ihl = (ip[0] & 15) * 4
    src = '.'.join(map(str, ip[12:16])); dst = '.'.join(map(str, ip[16:20]))
    sp, dp, ulen = struct.unpack_from('>HHH', ip, ihl)
    udp = ip[ihl + 8:]
    if len(udp) < 14 or udp[0] >> 6 != 2:
        continue
    pt = udp[1] & 0x7F
    flows[(src, dst, pt)].append((ulen - 8 - 12, udp[12:16]))
for (src, dst, pt), pk in flows.items():
    sizes = collections.Counter(p[0] for p in pk)
    heads = collections.Counter(p[1][:2].hex() for p in pk)
    print('%s -> %s pt %d: %d pkts, payload sizes %s, first bytes %s'
          % (src, dst, pt, len(pk), dict(sizes.most_common(4)), dict(heads.most_common(5))))
print('AMR 12.2: octet-aligned payload 33 bytes, starts CMR byte xF0 then TOC 0x3c;'
      ' bandwidth-efficient 32 bytes; SID: OA 7 bytes (TOC 0x44), BE 6 bytes')
