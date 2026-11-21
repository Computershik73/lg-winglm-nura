#!/usr/bin/env python3
# Dump a Qualcomm QMI IDL service object from an aarch64 .so (no pyelftools)
# usage: qmiidl.py lib.so symbol
import sys, struct

data = bytearray(open(sys.argv[1], 'rb').read())
sym = sys.argv[2]

e_shoff, = struct.unpack_from('<Q', data, 0x28)
e_shentsize, e_shnum, e_shstrndx = struct.unpack_from('<HHH', data, 0x3A)
secs = []
for i in range(e_shnum):
    o = e_shoff + i * e_shentsize
    name, typ, flags, addr, off, size, link, info, align, entsize = \
        struct.unpack_from('<IIQQQQIIQQ', data, o)
    secs.append(dict(name=name, type=typ, addr=addr, off=off, size=size,
                     link=link, entsize=entsize))
shstr = secs[e_shstrndx]
for s in secs:
    n = data[shstr['off'] + s['name']:]
    s['n'] = n[:n.index(0)].decode()

# virtual memory image
mem = {}
def v2o(va):
    for s in secs:
        if s['addr'] and s['addr'] <= va < s['addr'] + s['size'] and s['type'] != 8:
            return s['off'] + va - s['addr']
    return None

relocs = {}
for s in secs:
    if s['type'] == 4:  # RELA
        for k in range(s['size'] // 24):
            r_off, r_info, r_add = struct.unpack_from('<QQq', data, s['off'] + 24 * k)
            if r_info & 0xffffffff == 1027:  # R_AARCH64_RELATIVE
                relocs[r_off] = r_add
            else:
                relocs.setdefault(r_off, ('sym', r_info >> 32, r_add))

def ptr(va):
    r = relocs.get(va)
    if isinstance(r, int):
        return r
    if r is not None:
        return r
    o = v2o(va)
    return struct.unpack_from('<Q', data, o)[0]

def rd(fmt, va):
    return struct.unpack_from(fmt, data, v2o(va))

# find symbol
dynsym = [s for s in secs if s['n'] == '.dynsym'][0]
dynstr = secs[dynsym['link']]
symva = None
for k in range(dynsym['size'] // 24):
    st_name, st_info, st_other, st_shndx, st_value, st_size = \
        struct.unpack_from('<IBBHQQ', data, dynsym['off'] + 24 * k)
    n = data[dynstr['off'] + st_name:]
    n = n[:n.index(0)].decode()
    if n == sym:
        symva = st_value
print('object at', hex(symva))
lib_ver, idl_ver, svc_id, max_len = rd('<IIII', symva)
n_msgs = rd('<HHH', symva + 16)
tbls = [ptr(symva + 24 + 8 * i) for i in range(3)]
p_type = ptr(symva + 48)
minor, = rd('<I', symva + 56)
print('lib_ver %d idl_ver %d service_id %d (0x%x) max_msg_len %d minor %d' %
      (lib_ver, idl_ver, svc_id, svc_id, max_len, minor))
names = ['req', 'resp', 'ind']
msgtab = {}
for i in range(3):
    print('--', names[i], n_msgs[i], 'entries @', tbls[i])
    for k in range(n_msgs[i]):
        mid, tid, mlen = rd('<HHH', tbls[i] + 6 * k)
        msgtab.setdefault(names[i], []).append((mid, tid, mlen))
        print('   msg 0x%04x  table_idx 0x%04x  max_len %d' % (mid, tid, mlen))

# type table
if isinstance(p_type, int):
    n_types, n_messages, n_ref = rd('<HHB', p_type)
    p_types = ptr(p_type + 8)
    p_messages = ptr(p_type + 16)
    print('type table: n_types %d n_messages %d n_ref %d' % (n_types, n_messages, n_ref))
    # message table entries: c_struct_sz u32, p_encoded u64 ? (try 16-byte entries)
    want = [int(x, 0) for x in sys.argv[3:]]
    for (kind, lst) in msgtab.items():
        for mid, tid, mlen in lst:
            if want and mid not in want:
                continue
            idx = tid & 0xff
            e = p_messages + 16 * idx
            csz, = rd('<I', e)
            penc = ptr(e + 8)
            enc = bytes(data[v2o(penc):v2o(penc) + 64]) if isinstance(penc, int) else b''
            print('%s 0x%04x: c_struct_sz %d enc %s' % (kind, mid, csz, enc.hex()))
