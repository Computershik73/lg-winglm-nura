#!/usr/bin/python3
"""Step 1 probe: talk to the modem MMPF engine without starting media.
clear all -> create session 0 -> get state -> destroy session 0."""
import struct
import sys
import time

sys.path.insert(0, '/usr/lib/winglm-volte')
sys.path.insert(0, '/tmp/volte')
import mmpf


def drain(m, t):
    end = time.time() + t
    while time.time() < end:
        for typ, sess, data in m.indications(0.2):
            print('  IND', mmpf.describe(typ, sess, data), flush=True)


m = mmpf.Mmpf()
print('QMI 703 at', m.qmi.addr, flush=True)
for name, typ, sess, data in (('clear-all', mmpf.CLEARALL, 0, b''),
                              ('create', mmpf.CREATE, 0, b''),
                              ('getstate-rx', mmpf.GETSTATE, 0, struct.pack('<I', mmpf.RX)),
                              ('destroy', mmpf.DESTROY, 0, b'')):
    try:
        m.send(typ, sess, data)
        print(name, 'sent ok', flush=True)
    except Exception as e:
        print(name, 'FAILED', e, flush=True)
    drain(m, 1.5)
m.close()
