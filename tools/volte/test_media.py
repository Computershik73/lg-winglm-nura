#!/usr/bin/python3
"""loopback test of media.Relay: fake network (AMR-WB) and fake Calls (PCMA)"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gi.repository import GLib, Gst
from media import Relay

r = Relay('127.0.0.1', print)
NET_REMOTE, CALLS = 47000, 47002
r.start('127.0.0.1', NET_REMOTE, 116, 'AMR-WB', CALLS, 2)

# fake network sends AMR-WB to the relay, fake Calls sends PCMA
net_tx = Gst.parse_launch(
    'audiotestsrc freq=440 is-live=true ! audio/x-raw,rate=16000,channels=1 ! voamrwbenc band-mode=2 ! '
    'rtpamrpay pt=116 ! udpsink host=127.0.0.1 port=%d' % r.net_port)
calls_tx = Gst.parse_launch(
    'audiotestsrc freq=880 is-live=true ! audio/x-raw,rate=8000,channels=1 ! alawenc ! rtppcmapay pt=8 ! '
    'udpsink host=127.0.0.1 port=%d' % r.loc_port)
# receivers: count decoded buffers
cnt = {'calls': 0, 'net': 0}
calls_rx = Gst.parse_launch(
    'udpsrc port=%d caps="application/x-rtp,media=audio,clock-rate=8000,encoding-name=PCMA,payload=8" ! '
    'rtppcmadepay ! alawdec ! fakesink name=s signal-handoffs=true' % CALLS)
net_rx = Gst.parse_launch(
    'udpsrc port=%d caps="application/x-rtp,media=audio,clock-rate=16000,encoding-name=AMR-WB,'
    'encoding-params=(string)1,octet-align=(string)1,payload=116" ! rtpamrdepay ! amrwbdec ! '
    'fakesink name=s signal-handoffs=true' % NET_REMOTE)
calls_rx.get_by_name('s').connect('handoff', lambda *a: cnt.__setitem__('calls', cnt['calls'] + 1))
net_rx.get_by_name('s').connect('handoff', lambda *a: cnt.__setitem__('net', cnt['net'] + 1))
for p in (calls_rx, net_rx, net_tx, calls_tx):
    p.set_state(Gst.State.PLAYING)
loop = GLib.MainLoop()
GLib.timeout_add(4000, loop.quit)
loop.run()
print('decoded buffers after 4 s: towards Calls %d, towards network %d' % (cnt['calls'], cnt['net']))
for p in (calls_rx, net_rx, net_tx, calls_tx):
    p.set_state(Gst.State.NULL)
r.stop()
