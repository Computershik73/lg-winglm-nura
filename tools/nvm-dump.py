import struct, sys
d = open(sys.argv[1], "rb").read()
off = 0
tl = struct.unpack_from("<I", d, off)[0]
print("outer type", tl & 0xFF, "len", tl >> 8, "file", len(d))
if tl & 0xFF == 4:
    off = 4
    tl = struct.unpack_from("<I", d, off)[0]
    print("inner type", tl & 0xFF, "len", tl >> 8)
length = tl >> 8
idx = off + 4
n = 0
while idx + 12 <= off + 4 + length:
    tag, tlen = struct.unpack_from("<HH", d, idx)
    n += 1
    if tag in (2, 17, 27):
        print("tag %3d len %3d: %s" % (tag, tlen, d[idx + 12:idx + 12 + min(tlen, 16)].hex()))
    idx += 12 + tlen
print(n, "tags, end at", idx, "next header:", d[idx:idx + 4].hex() if idx + 4 <= len(d) else "-")
