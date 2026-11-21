#!/usr/bin/python3
"""Annotate objdump output of an AArch64 ELF: resolve adrp+add/ldr to
strings and GOT/pointer values (with RELATIVE relocations applied).
usage: elfx.py LIB DIS FUNC_REGEX [FUNC_REGEX...]   (prints matching functions)
       elfx.py LIB - ptrs ADDR N                     (dump N pointers -> strings)"""
import re, struct, sys

lib = sys.argv[1]
d = open(lib, 'rb').read()
shoff, = struct.unpack_from('<Q', d, 0x28)
shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3A)
secs = [struct.unpack_from('<IIQQQQIIQQ', d, shoff + i * shentsize) for i in range(shnum)]
strtab = secs[shstrndx]


def nm(o):
    s = d[strtab[4] + o:]
    return s[:s.index(0)].decode()


S = {nm(s[0]): s for s in secs}
# program headers for vaddr -> file offset
phoff, = struct.unpack_from('<Q', d, 0x20)
phentsize, phnum = struct.unpack_from('<HH', d, 0x36)
loads = []
for i in range(phnum):
    p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from('<IIQQQQQQ', d, phoff + i * phentsize)
    if p_type == 1:
        loads.append((p_vaddr, p_offset, p_filesz))


def off(va):
    for v, o, sz in loads:
        if v <= va < v + sz:
            return va - v + o
    return None


# dynamic symbols
syms = {}
ds = S.get('.dynsym')
if ds:
    dstr = secs[ds[6]]
    for k in range(ds[5] // 24):
        st_name, st_info, st_other, st_shndx, st_value, st_size = struct.unpack_from('<IBBHQQ', d, ds[4] + 24 * k)
        s = d[dstr[4] + st_name:]
        syms[k] = (s[:s.index(0)].decode(), st_value)
def aps2(data):
    """decode Android packed relocations (APS2)"""
    pos = [4]

    def sleb():
        res = shift = 0
        while True:
            b = data[pos[0]]
            pos[0] += 1
            res |= (b & 0x7f) << shift
            shift += 7
            if not b & 0x80:
                if b & 0x40:
                    res -= 1 << shift
                return res
    n = sleb()
    offset = sleb()
    addend = 0
    out = []
    while len(out) < n:
        gsize = sleb()
        gflags = sleb()
        if gflags & 2:
            gdelta = sleb()
        if gflags & 1:
            info = sleb()
        if gflags & 8 and gflags & 4:
            addend += sleb()
        elif not gflags & 8:
            addend = 0
        for _ in range(gsize):
            offset += gdelta if gflags & 2 else sleb()
            if not gflags & 1:
                info = sleb()
            if gflags & 8 and not gflags & 4:
                addend += sleb()
            out.append((offset, info & 0xffffffffffffffff, addend))
    return out


rel = {}
for name in ('.rela.dyn', '.rela.plt'):
    r = S.get(name)
    if not r:
        continue
    if d[r[4]:r[4] + 4] == b'APS2':
        entries = aps2(d[r[4]:r[4] + r[5]])
    else:
        entries = [struct.unpack_from('<QQq', d, r[4] + 24 * k) for k in range(r[5] // 24)]
    for r_off, r_info, r_add in entries:
        typ, sym = r_info & 0xffffffff, r_info >> 32
        if typ == 1027:  # RELATIVE
            rel[r_off] = ('v', r_add)
        else:
            sn, sv = syms.get(sym, ('?', 0))
            rel[r_off] = ('s', sn if not sv else sv + r_add, sn)


def u64(va):
    if va in rel:
        r = rel[va]
        return r[1]
    o = off(va)
    return struct.unpack_from('<Q', d, o)[0] if o is not None else None


def cstr(va):
    o = off(va)
    if o is None:
        return None
    e = d.find(b'\0', o, o + 300)
    s = d[o:e]
    if len(s) >= 3 and all(32 <= c < 127 or c in (9, 10) for c in s):
        return s.decode()
    return None


def desc(va):
    s = cstr(va)
    if s:
        return repr(s)
    if va in rel:
        r = rel[va]
        if r[0] == 's':
            return 'ptr->%s' % (r[2],)
        t = cstr(r[1])
        return 'ptr->%#x%s' % (r[1], (' ' + repr(t)) if t else '')
    return None


if sys.argv[2] == '-':
    if sys.argv[3] == 'ptrs':
        a = int(sys.argv[4], 16)
        for i in range(int(sys.argv[5])):
            v = u64(a + 8 * i)
            print(i, hex(v) if isinstance(v, int) else v, cstr(v) if isinstance(v, int) else '')
    elif sys.argv[3] == 'u32':
        a = int(sys.argv[4], 16)
        o = off(a)
        n = int(sys.argv[5])
        print([hex(x) for x in struct.unpack_from('<%dI' % n, d, o)])
    elif sys.argv[3] == 'u8':
        a = int(sys.argv[4], 16)
        o = off(a)
        print(list(d[o:o + int(sys.argv[5])]))
    sys.exit()

pats = [re.compile(p) for p in sys.argv[3:]]
regs = {}
show = False
for line in open(sys.argv[2], errors='replace'):
    if re.match(r'^[0-9a-f]+ <', line):
        show = any(p.search(line) for p in pats) and '@plt' not in line
        regs = {}
        if show:
            print()
    if not show:
        continue
    line = line.rstrip('\n')
    m = re.match(r'\s+([0-9a-f]+):\s+(\S+)\s+(.*)', line)
    note = ''
    if m:
        op, args = m.group(2), m.group(3)
        a = [x.strip() for x in args.split(',')]
        try:
            if op == 'adrp':
                regs[a[0]] = int(a[1].split()[0], 16)
            elif op == 'add' and len(a) >= 3 and a[1] in regs and a[2].startswith('#'):
                v = regs[a[1]] + int(a[2][1:].split()[0], 0)
                regs[a[0]] = v
                note = desc(v) or ''
            elif op in ('ldr', 'ldrb', 'ldrh', 'ldrsw') and len(a) >= 2:
                mm = re.match(r'\[(x\d+), #(-?\w+)\]', ','.join(a[1:]).replace(' ', ''))
                if mm and mm.group(1) in regs:
                    va = regs[mm.group(1)] + int(mm.group(2), 0)
                    if op == 'ldr' and a[0].startswith('x'):
                        v = u64(va)
                        note = 'GOT[%#x]=%s' % (va, (hex(v) if isinstance(v, int) else v))
                        if isinstance(v, int):
                            t = desc(v)
                            if t:
                                note += ' ' + t
                    else:
                        note = '[%#x]' % va
                    regs.pop(a[0], None)
                else:
                    regs.pop(a[0], None)
            elif a and a[0] in regs and op not in ('str', 'stp', 'strb', 'strh', 'cmp', 'cbz', 'cbnz', 'tbz', 'tbnz', 'stur'):
                regs.pop(a[0], None)
        except (ValueError, IndexError):
            pass
    print(line + (('   ; ' + note) if note else ''))
