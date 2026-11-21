import struct, sys, collections
for path in sys.argv[1:]:
    try:
        d = open(path, "rb").read()
    except OSError as e:
        print(path, e); continue
    n = len(d) // 24
    cnt = collections.Counter()
    xs, ys = [], []
    t0 = t1 = None
    downs = 0
    for i in range(n):
        sec, usec, typ, code, val = struct.unpack_from("<qqHHi", d, i * 24)
        t = sec + usec / 1e6
        t0 = t if t0 is None else t0
        t1 = t
        cnt[(typ, code)] += 1
        if typ == 3 and code == 0x35: xs.append(val)
        if typ == 3 and code == 0x36: ys.append(val)
        if typ == 1 and code == 0x14a and val == 1: downs += 1
    print(f"{path}: {n} events, span {0 if t0 is None else t1 - t0:.1f}s, BTN_TOUCH down x{downs}")
    if xs: print(f"  MT X {min(xs)}..{max(xs)}  MT Y {min(ys) if ys else '-'}..{max(ys) if ys else '-'}")
    print("  top codes:", ", ".join(f"{t}/{hex(c)}:{k}" for (t, c), k in cnt.most_common(8)))
