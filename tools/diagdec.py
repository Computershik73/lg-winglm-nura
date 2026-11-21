#!/usr/bin/env python3
# Decode diagcap.py output: F3 messages (0x79 legacy, 0x99 QShrink4 via the
# modem's qdsp6m.qdb) and event ids.  usage: diagdec.py diag.bin qdb.txt
import sys, struct, re

LVL = {1: 'L', 2: 'M', 4: 'H', 8: 'E', 16: 'F'}


def load_qdb(path):
    db = {}
    inside = False
    with open(path, 'rb') as f:
        for raw in f:
            line = raw.decode('latin-1').rstrip('\r\n')
            if line.startswith('<Content>'):
                inside = True
                continue
            if line.startswith('<\\Content>'):
                break
            if not inside:
                continue
            parts = line.split(':', 5)
            if len(parts) < 6:
                continue
            try:
                db[int(parts[0])] = (int(parts[1]), int(parts[2]), parts[3],
                                     parts[4], parts[5])
            except ValueError:
                pass
    return db


SPEC = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|z|j|t|L)?([diouxXcspfgeEG%])')


def cfmt(fmt, args, sizes=None):
    out = []
    pos = 0
    ai = 0
    for m in SPEC.finditer(fmt):
        out.append(fmt[pos:m.start()])
        pos = m.end()
        conv = m.group(1)
        if conv == '%':
            out.append('%')
            continue
        if ai >= len(args):
            out.append('<?>')
            continue
        v = args[ai]
        sz = sizes[ai] if sizes else 4
        ai += 1
        if conv in 'di':
            bits = 8 * sz
            if v >= 1 << (bits - 1):
                v -= 1 << bits
            out.append(str(v))
        elif conv in 'xX':
            out.append('%x' % v)
        elif conv == 'p':
            out.append('0x%x' % v)
        elif conv == 'c':
            out.append(chr(v & 0x7f) if 32 <= (v & 0xff) < 127 else '?')
        elif conv == 's':
            out.append('<str@%x>' % v)
        else:
            out.append(str(v))
    out.append(fmt[pos:])
    return ''.join(out)


def main():
    data = open(sys.argv[1], 'rb').read()
    db = load_qdb(sys.argv[2])
    i = 0
    t0 = None
    while i + 12 <= len(data):
        ts, ln = struct.unpack_from('<dI', data, i)
        p = data[i + 12:i + 12 + ln]
        i += 12 + ln
        if t0 is None:
            t0 = ts
        rel = '%7.3f' % (ts - t0)
        tag = ''
        if p[:1] == b'\x98' and len(p) > 8:
            tag = '[pd%d]' % struct.unpack_from('<I', p, 4)[0]
            p = p[8:]
        if not p:
            continue
        c = p[0]
        try:
            if c == 0x79:
                nargs = p[2]
                line, ssid, mask = struct.unpack_from('<HHI', p, 12)
                args = list(struct.unpack_from('<%dI' % nargs, p, 20))
                rest = p[20 + 4 * nargs:]
                fmt, _, rest = rest.partition(b'\0')
                fn = rest.partition(b'\0')[0]
                print(rel, tag, LVL.get(mask & 0x1f, '%x' % mask), ssid,
                      '%s:%d' % (fn.decode('latin-1'), line),
                      cfmt(fmt.decode('latin-1'), args))
            elif c == 0x99:
                b2 = p[2]
                n = b2 & 0x0f
                sz = (b2 >> 4) or 4
                idx = struct.unpack_from('<I', p, 12)[0]
                off = 18
                if off + n * sz > len(p):
                    raise struct.error('short')
                args = [int.from_bytes(p[off + k * sz:off + (k + 1) * sz], 'little')
                        for k in range(n)]
                e = db.get(idx)
                if e:
                    mask, ssid, line, fn, fmt = e
                    print(rel, tag, LVL.get(mask & 0x1f, '%x' % mask), ssid,
                          '%s:%s' % (fn, line), cfmt(fmt, args, [sz] * n))
                else:
                    print(rel, tag, '?', 'idx=%d' % idx, args, p.hex())
            elif c == 0x60:
                pass
            elif c in (0x7d, 0x00, 0x73, 0x82):
                pass
            else:
                print(rel, tag, 'pkt', p[:40].hex())
        except struct.error:
            print(rel, tag, 'short', p.hex())


main()
