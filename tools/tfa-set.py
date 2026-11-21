#!/usr/bin/python3
"""set a TFA9878 bit field (read-modify-write) through the driver's sysfs
reg/rw (root). usage: tfa-set.py REG POS LEN VALUE  (prints old -> new)"""
import sys

D = '/sys/bus/i2c/devices/3-0034/'


def rd(reg):
    with open(D + 'reg', 'wb', buffering=0) as f:
        f.write(bytes([reg]))
    with open(D + 'rw', 'rb', buffering=0) as f:
        b = f.read(2)
    return (b[0] << 8) | b[1]


def wr(reg, v):
    with open(D + 'reg', 'wb', buffering=0) as f:
        f.write(bytes([reg]))
    with open(D + 'rw', 'wb', buffering=0) as f:
        f.write(bytes([v >> 8, v & 0xff]))


reg, pos, ln, val = (int(a, 0) for a in sys.argv[1:5])
mask = ((1 << ln) - 1) << pos
old = rd(reg)
new = (old & ~mask) | ((val << pos) & mask)
wr(reg, new)
print('reg 0x%02x: 0x%04x -> 0x%04x (field %d -> %d), readback 0x%04x'
      % (reg, old, new, (old & mask) >> pos, val, rd(reg)))
