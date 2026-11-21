import struct, sys, re, subprocess
# boot-relative timeline of touches (BTN_TOUCH down) vs swivel kernel messages
d = open(sys.argv[1], "rb").read()
mark = float(open(sys.argv[2]).read())
# input timestamps are CLOCK_REALTIME; convert using the current offset
import time
off = time.clock_gettime(time.CLOCK_REALTIME) - time.clock_gettime(time.CLOCK_BOOTTIME)
touches = []
for i in range(len(d) // 24):
    sec, usec, typ, code, val = struct.unpack_from("<qqHHi", d, i * 24)
    if typ == 1 and code == 0x14a and val == 1:
        touches.append(sec + usec / 1e6 - off)
log = subprocess.run(["dmesg"], capture_output=True, text=True).stdout.splitlines()
events = []
for line in log:
    m = re.match(r"\[\s*([0-9.]+)\]", line)
    if not m: continue
    t = float(m.group(1))
    if t < mark: continue
    if re.search(r"swivel|SWIVEL|INTERRUPT", line):
        events.append((t, line.split("] ", 1)[1][:110]))
for t in touches:
    events.append((t, "touch down"))
events.sort()
last = None
for t, s in events:
    if s == "touch down" and last == "touch down":
        cnt[0] += 1
        continue
    if s == "touch down":
        cnt = [1]
        print(f"{t:9.2f}  touch down (burst start)")
    else:
        if last == "touch down": print(f"{'':9}  ... {cnt[0]} touches in burst")
        print(f"{t:9.2f}  {s}")
    last = s
if last == "touch down": print(f"{'':9}  ... {cnt[0]} touches in burst")
print("total touches:", len(touches))
