#!/usr/bin/env python3
"""Rebuild Module.symvers of a running arm64 4.19 kernel from its Image.

The exported symbol tables (__ksymtab*, PREL32 entries: value_offset,
name_offset) and the CRC tables (__kcrctab*, one u32 per symbol, same
order) are in the uncompressed Image; /proc/kallsyms of the running kernel
gives their addresses, Image offset = address - _text.

usage: symvers-from-image.py Image kallsyms.txt > Module.symvers
"""
import struct
import sys

image = open(sys.argv[1], "rb").read()
syms = {}
for line in open(sys.argv[2]):
    parts = line.split()
    if len(parts) >= 3:
        syms.setdefault(parts[2], int(parts[0], 16))

text = syms["_text"]


def off(addr):
    return addr - text


def cstr(o):
    return image[o:image.index(b"\0", o)].decode()


out = []
for sec, kind in (("", "EXPORT_SYMBOL"), ("_gpl", "EXPORT_SYMBOL_GPL")):
    start, stop = syms["__start___ksymtab" + sec], syms["__stop___ksymtab" + sec]
    cstart, cstop = syms["__start___kcrctab" + sec], syms["__stop___kcrctab" + sec]
    n = (stop - start) // 8
    assert n == (cstop - cstart) // 4, "table sizes differ for %r" % sec
    for i in range(n):
        entry = start + 8 * i
        _value_off, name_off = struct.unpack_from("<ii", image, off(entry))
        name = cstr(off(entry + 4 + name_off))
        crc, = struct.unpack_from("<I", image, off(cstart) + 4 * i)
        out.append("0x%08x\t%s\tvmlinux\t%s" % (crc, name, kind))

# sanity: names must be sorted (the linker sorts both tables by name)
names = [l.split("\t")[1] for l in out]
sys.stderr.write("%d symbols, first %s, last %s\n" % (len(out), names[0], names[-1]))
print("\n".join(out))
