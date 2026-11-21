import re, sys
for line in open(sys.argv[1]):
    if 'sendmsg' not in line and 'recvmsg' not in line:
        continue
    for m in re.finditer(r'iov_base="((?:\\x[0-9a-f]{2})+)"', line):
        b = bytes(int(x, 16) for x in re.findall(r'\\x([0-9a-f]{2})', m.group(1)))
        if len(b) < 28:
            continue
        typ = int.from_bytes(b[4:6], 'little')
        if typ == 2 and 'recvmsg' in line:   # NLMSG_ERROR
            err = int.from_bytes(b[16:20], 'little', signed=True)
            otyp = int.from_bytes(b[24:26], 'little')
            if otyp == 24:
                print('  -> error %d for RTM_NEWROUTE' % err)
            continue
        if typ != 24 or 'sendmsg' not in line:
            continue
        flags = int.from_bytes(b[6:8], 'little')
        fam, dlen, slen, tos, table, proto, scope, rtype = b[16:24]
        rflags = int.from_bytes(b[24:28], 'little')
        print('RTM_NEWROUTE nlflags=%#x family=%d dst_len=%d table=%d proto=%d scope=%d type=%d rtm_flags=%#x'
              % (flags, fam, dlen, table, proto, scope, rtype, rflags))
        off = 28
        while off + 4 <= len(b):
            alen = int.from_bytes(b[off:off + 2], 'little')
            atype = int.from_bytes(b[off + 2:off + 4], 'little')
            if alen < 4:
                break
            print('   attr %d len %d: %s' % (atype, alen, b[off + 4:off + alen].hex()))
            off += (alen + 3) & ~3
