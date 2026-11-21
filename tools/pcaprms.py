#!/usr/bin/python3
"""RMS per second of PCMA RTP payloads per flow in a pcap (DLT_NULL/RAW/EN10MB)"""
import struct, sys, collections


def alaw(a):
    a ^= 0x55
    t = (a & 0x0F) << 4
    seg = (a & 0x70) >> 4
    t += 8 if seg == 0 else 0x108
    if seg > 1:
        t <<= seg - 1
    return t if a & 0x80 else -t


def packets(path):
    d = open(path, 'rb').read()
    magic, = struct.unpack_from('<I', d, 0)
    linktype, = struct.unpack_from('<I', d, 20)
    off = 24
    while off + 16 <= len(d):
        ts, tus, incl, orig = struct.unpack_from('<IIII', d, off)
        pkt = d[off + 16:off + 16 + incl]
        off += 16 + incl
        if linktype == 0:      # DLT_NULL
            ip = pkt[4:]
        elif linktype == 1:
            ip = pkt[14:]
        elif linktype in (101, 12, 228):
            ip = pkt
        elif linktype == 113:  # linux cooked
            ip = pkt[16:]
        else:
            ip = pkt
        if len(ip) < 28 or ip[0] >> 4 != 4 or ip[9] != 17:
            continue
        ihl = (ip[0] & 15) * 4
        src = '.'.join(map(str, ip[12:16])); dst = '.'.join(map(str, ip[16:20]))
        sp, dp = struct.unpack_from('>HH', ip, ihl)
        yield ts + tus / 1e6, (src, sp, dst, dp), ip[ihl + 8:]


flows = collections.defaultdict(list)
for t, f, udp in packets(sys.argv[1]):
    if len(udp) > 12 and udp[0] >> 6 == 2 and (udp[1] & 0x7F) == 8:
        flows[f].append((t, udp[12:]))
for f, pk in flows.items():
    t0 = pk[0][0]
    secs = collections.defaultdict(list)
    for t, pl in pk:
        secs[int(t - t0)] += [alaw(b) for b in pl]
    rms = [int((sum(v * v for v in x) / len(x)) ** 0.5) for k, x in sorted(secs.items())]
    print('%s:%d -> %s:%d  %d pkts, payload %d bytes captured, RMS/s: %s' % (
        f[0], f[1], f[2], f[3], len(pk), len(pk[0][1]), ' '.join(map(str, rms))))
