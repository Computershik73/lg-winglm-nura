#!/usr/bin/python3
"""read TFA9878 registers through the driver's sysfs reg/rw (root)"""
import sys
D = '/sys/bus/i2c/devices/3-0034/'


def rd(reg):
    with open(D + 'reg', 'wb', buffering=0) as f:
        f.write(bytes([reg]))
    with open(D + 'rw', 'rb', buffering=0) as f:
        b = f.read(2)
    return (b[0] << 8) | b[1]


def field(v, pos, ln):
    return (v >> pos) & ((1 << ln) - 1)


for reg in [int(a, 0) for a in sys.argv[1:]] or [0x52, 0x5f]:
    v = rd(reg)
    print('reg 0x%02x = 0x%04x' % (reg, v))
v52, v5f = rd(0x52), rd(0x5f)
print('AMPGAIN (0x52 bits 5..12) = %d, TDMSPKG (0x5f bits 6..9) = %d, TDMDCG (0x5f bits 2..5) = %d'
      % (field(v52, 5, 8), field(v5f, 6, 4), field(v5f, 2, 4)))
