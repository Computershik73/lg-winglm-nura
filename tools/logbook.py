"""Summarise logbookd.db: per boot, count and the last N messages."""
import sqlite3
import sys

db = sys.argv[1]
tail = int(sys.argv[2]) if len(sys.argv) > 2 else 25
c = sqlite3.connect(db)
cols = [r[1] for r in c.execute("pragma table_info(log)")]
print("columns:", cols)
boots = c.execute(
    "select boot_id, count(*), min(received), max(received) from log "
    "group by boot_id order by min(received)").fetchall()
for i, (bid, n, t0, t1) in enumerate(boots):
    print(f"\n### boot {i}: {bid.hex()[:8]} msgs={n} span={(t1 - t0) / 1e6 if t1 > 1e12 else t1 - t0:.0f}s")
    if i < len(boots) - 4:
        continue
    rows = c.execute(
        "select app, message from log where boot_id=? order by received desc, seq desc limit ?",
        (bid, tail)).fetchall()
    for app, msg in reversed(rows):
        print(f"  [{app}] {msg[:170]}")
