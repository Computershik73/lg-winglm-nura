"""Map QFIL ReadData_* dumps onto the GPT and report coverage.

usage: python -I qfil_coverage.py <qfil COMPORT dir> <PartitionsList.xml>
"""
import os
import re
import struct
import sys
import uuid
import xml.etree.ElementTree as ET

SECTOR = 4096
qdir, plist = sys.argv[1], sys.argv[2]

parts = {}  # (lun, label) -> (start, num)
src = {}

# 1) GPT dumps written by QFIL
for name in sorted(os.listdir(qdir)):
    m = re.fullmatch(r"fh_gpt_header_(\d+)", name)
    if not m:
        continue
    lun = int(m.group(1))
    hdr = open(os.path.join(qdir, name), "rb").read()
    if hdr[:8] != b"EFI PART":
        print(f"LUN{lun}: bad GPT header")
        continue
    n_ent, ent_sz = struct.unpack_from("<II", hdr, 80)
    ents = open(os.path.join(qdir, f"fh_gpt_entries_{lun}"), "rb").read()
    have = len(ents) // ent_sz
    used = 0
    for i in range(min(n_ent, have)):
        e = ents[i * ent_sz:(i + 1) * ent_sz]
        if e[:16] == b"\0" * 16:
            continue
        first, last = struct.unpack_from("<QQ", e, 32)
        label = e[56:128].decode("utf-16-le").rstrip("\0")
        parts[(lun, label)] = (first, last - first + 1)
        src[(lun, label)] = "gpt"
        used += 1
    print(f"LUN{lun}: GPT says {n_ent} slots, dump has {have}, used {used}")

# 2) PartitionsList.xml (fills anything the short GPT dumps miss)
for p in ET.parse(plist).getroot().iter("partition"):
    key = (int(p.get("physical_partition_number")), p.get("label"))
    val = (int(p.get("start_sector")), int(p.get("num_partition_sectors")))
    if key not in parts:
        parts[key] = val
        src[key] = "xml"
    elif parts[key] != val:
        print(f"MISMATCH {key}: gpt={parts[key]} xml={val}")

# 3) reads
reads = []
for name in os.listdir(qdir):
    m = re.fullmatch(r"ReadData_ufs_Lun(\d+)_0x([0-9a-f]+)_Len(\d+)_DT_.*\.bin", name)
    if not m:
        continue
    lun, start, ln = int(m.group(1)), int(m.group(2), 16), int(m.group(3))
    size = os.path.getsize(os.path.join(qdir, name))
    reads.append((lun, start, ln, size == ln * SECTOR, name))

covered = {}
unmatched = []
for lun, start, ln, full, name in reads:
    hit = [k for k, (s, n) in parts.items() if k[0] == lun and s == start and n == ln]
    if hit:
        covered.setdefault(hit[0], []).append(full)
    else:
        unmatched.append((lun, start, ln, name))

print("\n== covered (lun, label, sectors, complete) ==")
for k in sorted(covered):
    print(f"  LUN{k[0]} {k[1]:<22} {parts[k][1]:>8}  {'OK' if all(covered[k]) else 'SHORT FILE'}"
          f"{'  x' + str(len(covered[k])) if len(covered[k]) > 1 else ''}")

print("\n== NOT read ==")
for k in sorted(parts):
    if k not in covered:
        print(f"  LUN{k[0]} {k[1]:<22} {parts[k][1]:>8} sectors ({parts[k][1] * SECTOR / 2**20:.1f} MiB) [{src[k]}]")

print("\n== reads not matching a partition ==")
for u in unmatched:
    print("  ", u)
