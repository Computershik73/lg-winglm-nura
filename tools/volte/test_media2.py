#!/usr/bin/python3
"""loopback test of the PulseAudio media path, run as root like the daemon"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gi
gi.require_version('Gst', '1.0')
from gi.repository import GLib, Gst
from media import Relay

r = Relay('127.0.0.1', print)
NET_REMOTE = 47000
r.start('127.0.0.1', NET_REMOTE, 97, 'AMR', None, 7, None)
net_tx = Gst.parse_launch(
    'audiotestsrc freq=600 volume=0.3 is-live=true ! audio/x-raw,rate=8000,channels=1 ! amrnbenc band-mode=7 ! '
    'rtpamrpay pt=97 ! udpsink host=127.0.0.1 port=%d' % r.net_port)
cnt = [0]
net_rx = Gst.parse_launch(
    'udpsrc port=%d caps="application/x-rtp,media=audio,clock-rate=8000,encoding-name=AMR,'
    'encoding-params=(string)1,octet-align=(string)1,payload=97" ! rtpamrdepay ! amrnbdec ! '
    'fakesink name=s signal-handoffs=true' % NET_REMOTE)
net_rx.get_by_name('s').connect('handoff', lambda *a: cnt.__setitem__(0, cnt[0] + 1))
for p in (net_rx, net_tx):
    p.set_state(Gst.State.PLAYING)
loop = GLib.MainLoop()
GLib.timeout_add(6000, loop.quit)
loop.run()
print('decoded mic buffers that reached the fake network:', cnt[0])
for p in (net_rx, net_tx):
    p.set_state(Gst.State.NULL)
r.stop()
