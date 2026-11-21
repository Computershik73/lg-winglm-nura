#!/usr/bin/python3
"""Earpiece needs a valid WCD938x Class-H mode (LG sets CLS_H_ULP at boot;
the driver starts at CLS_H_NORMAL, where the Class-H port is never
connected): insert it before every 'EAR_RDAC Switch' 1 in the UCM files."""
import re
import sys

for path in sys.argv[1:]:
    src = open(path, newline='').read()
    out = []
    n = 0
    for line in src.split('\n'):
        m = re.match(r"(\s*)cset \"name='EAR_RDAC Switch' 1\"", line)
        if m and not (out and 'CLS_H_ULP' in out[-1]):
            ind = m.group(1)
            out.append(ind + "cset \"name='RX_HPH_PWR_MODE' ULP\"")
            out.append(ind + "cset \"name='RX HPH Mode' CLS_H_ULP\"")
            n += 1
        out.append(line)
    open(path, 'w', newline='').write('\n'.join(out))
    print(path, n, 'insertions')
