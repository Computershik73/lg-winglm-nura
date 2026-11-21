#!/usr/bin/python3
"""Step 2 probe: modem media loopback without a call.
RTP goes from the modem's socket to its own IMS address (same port), so the
modem receives its own stream.  usage: mmpfprobe2.py [SECONDS]"""
import subprocess
import sys
import time

sys.path.insert(0, '/usr/lib/winglm-volte')
sys.path.insert(0, '/tmp/volte')
import mmpf
from ipadata import ims_profile

secs = float(sys.argv[1]) if len(sys.argv) > 1 else 6
ip = subprocess.run(['ip', '-4', '-o', 'addr', 'show', 'dev', 'rmnet_data1'],
                    capture_output=True, text=True).stdout.split()
ip = ip[ip.index('inet') + 1].split('/')[0]
prof = ims_profile()
port = 50010
print('IMS profile', prof, 'local port', port, flush=True)


def drain(m, t):
    end = time.time() + t
    while time.time() < end:
        for typ, sess, data in m.indications(0.2):
            print('  IND', mmpf.describe(typ, sess, data), flush=True)


m = mmpf.Mmpf()
S = 0
steps = [('clear-all', mmpf.CLEARALL, b''), ('create', mmpf.CREATE, b'')]
for mode in (mmpf.RX, mmpf.TX):
    steps += [('network-%d' % mode, mmpf.SETPROP,
               mmpf.network_prop(mode, ip, ip, port, port, profile=prof)),
              ('transport-%d' % mode, mmpf.SETPROP,
               mmpf.transport_prop(mode, 97, 97, 16000)),
              ('codec-%d' % mode, mmpf.SETPROP,
               mmpf.codec_prop(mode, mmpf.AMR_WB, 0x7))]
steps += [('txsource', mmpf.SETPROP, mmpf.txsource_prop()),
          ('start-rx', mmpf.REQUEST, mmpf.request(mmpf.R_START, mmpf.RX)),
          ('start-tx', mmpf.REQUEST, mmpf.request(mmpf.R_START, mmpf.TX))]
try:
    for name, typ, data in steps:
        m.send(typ, S, data)
        print(name, 'sent', len(data), flush=True)
        drain(m, 0.3)
    drain(m, secs)
finally:
    for name, typ, data in (('stop-tx', mmpf.REQUEST, mmpf.request(mmpf.R_STOP, mmpf.TX)),
                            ('stop-rx', mmpf.REQUEST, mmpf.request(mmpf.R_STOP, mmpf.RX)),
                            ('destroy', mmpf.DESTROY, b'')):
        try:
            m.send(typ, S, data)
            print(name, 'sent', flush=True)
        except Exception as e:
            print(name, 'failed', e, flush=True)
        drain(m, 0.5)
    m.close()
