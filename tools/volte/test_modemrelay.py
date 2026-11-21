#!/usr/bin/python3
"""dry run of ModemRelay + SDP glue without a call (remote = own IMS address)"""
import subprocess
import sys
import time

sys.path.insert(0, '/usr/lib/winglm-volte')
from gi.repository import GLib
import modemmedia
import sdp as SDP
from ipadata import ims_profile

ip = subprocess.run(['ip', '-4', '-o', 'addr', 'show', 'dev', 'rmnet_data1'],
                    capture_output=True, text=True).stdout.split()
ip = ip[ip.index('inet') + 1].split('/')[0]


def log(s):
    print(time.strftime('%H:%M:%S'), s, flush=True)


answer = '\r\n'.join([
    'v=0', 'o=- 1 1 IN IP4 %s' % ip, 's=-', 'c=IN IP4 %s' % ip, 't=0 0',
    'm=audio 50020 RTP/AVP 117 118', 'a=rtpmap:117 AMR-WB/16000/1',
    'a=fmtp:117 mode-change-capability=2;max-red=0;mode-set=0,1,2', 'a=rtpmap:118 telephone-event/16000',
    'a=fmtp:118 0-15', 'a=ptime:20', 'a=sendrecv']) + '\r\n'
ans = SDP.Sdp(answer)
ch = ans.pick_amr(be_ok=True)
log('pick_amr -> %s, dtmf %s, rtcp %s, AP pick %s' % (ch, ans.dtmf_pt(16000), ans.rtcp_port(), ans.pick_amr()))
r = modemmedia.ModemRelay(ip, log, ims_profile())
log('offer:\n' + SDP.net_offer(ip, r.net_port, modem=True))
pt, name, fmtp, oa = ch
r.start(ans.conn, ans.port, pt, name, None, 2, None, fmtp=fmtp, oa=oa, dtmf_pt=ans.dtmf_pt(16000),
        rtcp_port=ans.rtcp_port())
loop = GLib.MainLoop()
GLib.timeout_add_seconds(6, loop.quit)
loop.run()
r.stop()
log('answer for a BE offer:\n' + SDP.net_answer(ip, 50030, ans, ch))
