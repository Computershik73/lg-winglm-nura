"""Move QFIL ReadData_* dumps into <backup>/partitions/ named by partition label,
copy the GPT dumps alongside, then write a SHA256 manifest.

Same-volume os.rename only (no extra disk space). Never overwrites, never deletes.
usage: python -I qfil_organize.py <qfil COMPORT dir> <backup dir>
"""
import hashlib
import json
import os
import re
import shutil
import struct
import sys

S = 4096
qdir, bdir = sys.argv[1], sys.argv[2]
dest = os.path.join(bdir, "partitions")
os.makedirs(dest, exist_ok=True)
os.makedirs(os.path.join(dest, "gpt"), exist_ok=True)


def gpt_entries(hdr, ents):
    n, sz = struct.unpack_from("<II", hdr, 80)
    for i in range(min(n, len(ents) // sz)):
        e = ents[i * sz:(i + 1) * sz]
        if e[:16] == b"\0" * 16:
            continue
        first, last = struct.unpack_from("<QQ", e, 32)
        yield e[56:128].decode("utf-16-le").rstrip("\0"), first, last - first + 1


layout = {}  # (lun, start, len) -> label
for name in os.listdir(qdir):
    m = re.fullmatch(r"fh_gpt_header_(\d+)", name)
    if m:
        lun = int(m.group(1))
        hdr = open(os.path.join(qdir, name), "rb").read()
        ents = open(os.path.join(qdir, f"fh_gpt_entries_{lun}"), "rb").read()
        for label, start, ln in gpt_entries(hdr, ents):
            layout[(lun, start, ln)] = label
        for f in (name, f"fh_gpt_entries_{lun}"):
            shutil.copy2(os.path.join(qdir, f), os.path.join(dest, "gpt", f))

moved = []
for name in sorted(os.listdir(qdir)):
    m = re.fullmatch(r"ReadData_ufs_Lun(\d+)_0x([0-9a-f]+)_Len(\d+)_DT_(.*)\.bin", name)
    if not m:
        continue
    lun, start, ln = int(m.group(1)), int(m.group(2), 16), int(m.group(3))
    label = layout.get((lun, start, ln), f"unknown_{start}_{ln}")
    target = os.path.join(dest, f"lun{lun}_{label}.bin")
    k = 2
    while os.path.exists(target):  # repeated reads of the same partition
        target = os.path.join(dest, f"lun{lun}_{label}_{k}.bin")
        k += 1
    os.rename(os.path.join(qdir, name), target)
    moved.append({"file": os.path.relpath(target, bdir), "from": name, "lun": lun,
                  "start_sector": start, "sectors": ln})
    print(f"moved {name} -> {os.path.basename(target)}", flush=True)

# manifest over everything in the backup dir (top-level .bin + partitions/)
manifest = []
for root, _, files in os.walk(bdir):
    for f in sorted(files):
        if not f.endswith(".bin"):
            continue
        p = os.path.join(root, f)
        h = hashlib.sha256()
        with open(p, "rb") as fh:
            for chunk in iter(lambda: fh.read(16 << 20), b""):
                h.update(chunk)
        rel = os.path.relpath(p, bdir)
        entry = next((m for m in moved if m["file"] == rel), {"file": rel})
        entry.update(bytes=os.path.getsize(p), sha256=h.hexdigest().upper())
        manifest.append(entry)
        print(f"hashed {rel}", flush=True)

with open(os.path.join(bdir, "manifest.json"), "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, indent=1, ensure_ascii=False)
with open(os.path.join(bdir, "SHA256SUMS.txt"), "w", encoding="utf-8") as fh:
    for e in manifest:
        fh.write(f"{e['sha256']}  {e['file']}\n")
print(f"DONE: moved {len(moved)}, hashed {len(manifest)}")
