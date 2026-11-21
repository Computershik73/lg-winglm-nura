#!/usr/bin/python3
"""winglm-volte: VoLTE for the LG Wing on postmarketOS.

The LG modem firmware has no IMS client of its own (on Android LG's IMS app
does SIP), so this daemon is the IMS client: IMS PDN over IPA, ISIM AKA,
IPsec, registration, and a back-to-back user agent towards GNOME Calls,
which registers here as a plain SIP account (127.0.0.1:5070, "Use for Phone
Calls"). Audio: by default in the modem like on Android (LG's MMPF media
engine over the LG VSS IMS QMI service: RTP, AMR/AMR-WB and the DSP voice
path with its calibration, see modemmedia.py); fallback (or with
/etc/winglm-volte/ap-media): AMR-WB/AMR transcoded on the AP with GStreamer.
"""
import os
import re
import signal
import socket
import sys
import time
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gi.repository import GLib
try:
    gi_unix = __import__('gi.repository.GLibUnix', fromlist=['GLibUnix'])
    GLibUnix = gi_unix
except ImportError:
    GLibUnix = None

import sdp as SDP
from imsreg2 import ImsLink
from media import Relay
import modemmedia
from sipmsg import Msg, branch, rnd, response, uri_of, user_of, hostport_of, params

LOCAL_PORT = 5070
CALLS_EXPIRES = 60          # registration time granted to GNOME Calls
ECHO_TEST = '0000000'      # dialled in Calls: local audio loopback, no network
SECRETS = []


def mask(s):
    for x in SECRETS:
        if x:
            s = s.replace(x, '<***>')
    s = re.sub(r'\+?7\d{10}', lambda m: m.group(0)[:4] + '*******', s)
    s = re.sub(r'utran-cell-id-3gpp=[0-9A-Fa-f]+', 'utran-cell-id-3gpp=<cell>', s)
    return s


TRACE = None


def log(*a):
    """stdout (service log) and an fsync'd trace: a kernel crash in the IPA
    data path takes the unsynced service log with it"""
    global TRACE
    line = '%s %s' % (time.strftime('%H:%M:%S'), mask(' '.join(str(x) for x in a)))
    print(line, flush=True)
    try:
        if TRACE is None:
            TRACE = open('/var/log/winglm-volte.trace', 'a')
        TRACE.write(line + '\n')
        TRACE.flush()
        os.fsync(TRACE.fileno())
    except OSError:
        pass


def modem_ready():
    """IPA data path set up before the modem has attached (UL filter rules
    not installed yet) panics the kernel once traffic flows: wait for LTE
    with packet service and a settled system"""
    from imsreg2 import run
    up = float(open('/proc/uptime').read().split()[0])
    if up < 120:
        return 'uptime %d s' % up
    out = run('qmicli -d qrtr://0 --nas-get-system-info').stdout
    lte = out.split('LTE service:', 1)[1] if 'LTE service:' in out else ''
    lte = lte.split(' service:', 1)[0]
    if "Status: 'available'" not in lte or not re.search(r"Domain: '(ps|cs-ps)'", lte):
        return 'no LTE packet service'
    return None


def normalize(number, domain):
    n = re.sub(r'[^\d+*#]', '', number)
    if re.fullmatch(r'8\d{10}', n):
        n = '+7' + n[1:]
    elif re.fullmatch(r'7\d{10}', n):
        n = '+' + n
    if n.startswith('+'):
        return 'tel:' + n
    return 'tel:%s;phone-context=%s' % (n, domain)


class Dialog:
    """one side of a call"""

    def __init__(self):
        self.call_id = None
        self.local_tag = rnd(8)
        self.remote_tag = None
        self.local_uri = None
        self.remote_uri = None
        self.remote_target = None
        self.route = []
        self.cseq = 0
        self.invite = None          # INVITE we sent (UAC) or received (UAS)
        self.via = None             # where the INVITE came from (UAS)


class Call:
    def __init__(self, mgr, direction):
        self.mgr = mgr
        self.dir = direction        # 'mo' or 'mt'
        self.net = Dialog()
        self.loc = Dialog()
        self.relay = None
        self.state = 'init'
        self.net_offer = None
        self.net_choice = None
        self.calls_rtp = None
        self.rseq = 0
        self.pending_answer = None
        self.media_started = False
        self.answer_sent = False
        self.caller = None
        self.calls_ip = '127.0.0.1'


class Manager:
    def __init__(self):
        self.ims = None
        self.ims_state = 'idle'     # idle / starting / up / retry
        self.disabled = os.path.exists(self.GUARD)
        if self.disabled:
            log('the last IMS bring-up did not survive (kernel crash?): VoLTE off for this boot')
            self.guard(False)
        self.retry_src = None
        self.calls_expiry_src = None
        self.calls_contact = None
        self.calls = {}             # call-id (either leg) -> Call
        self.loc = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.loc.bind(('127.0.0.1', LOCAL_PORT))
        self.loc.setblocking(False)
        GLib.io_add_watch(self.loc.fileno(), GLib.IO_IN, self._loc_rx)
        self.fallback_route(True)
        self.write_status()
        GLib.timeout_add_seconds(10, self.write_status)

    # GNOME Calls only keeps a SIP account online while some default route
    # exists; without Wi-Fi (mobile data is not up) it would go offline and
    # VoLTE with it. A last-resort default route into a dummy interface keeps
    # it registered here; any real default route has a far lower metric.
    FALLBACK_IF, FALLBACK_IP = 'volte0', '198.18.0.1'

    def fallback_route(self, on):
        from imsreg2 import run
        if on:
            if not os.path.exists('/sys/class/net/' + self.FALLBACK_IF):
                run('ip link add %s type dummy' % self.FALLBACK_IF)
            run('ip addr replace %s/32 dev %s' % (self.FALLBACK_IP, self.FALLBACK_IF))
            run('ip link set %s up' % self.FALLBACK_IF)
            run('ip route replace default dev %s src %s metric 50000' % (self.FALLBACK_IF, self.FALLBACK_IP))
        else:
            run('ip link del %s' % self.FALLBACK_IF)

    # =============================================================== IMS link life cycle
    # IMS (and with it VoLTE for incoming calls) is only up while GNOME Calls
    # is registered here: without a UI to ring, calls stay on CS.
    GUARD = '/var/lib/winglm-volte/ipa-guard'

    def guard(self, on):
        """set before the data path comes up, cleared once IMS has run for a
        while: found at start-up it means the last bring-up crashed the phone
        (kernel), so this boot stays on CS instead of crashing again"""
        try:
            if on:
                os.makedirs(os.path.dirname(self.GUARD), exist_ok=True)
                with open(self.GUARD, 'w') as f:
                    f.write(str(int(time.time())))
                    f.flush()
                    os.fsync(f.fileno())
            elif os.path.exists(self.GUARD):
                os.remove(self.GUARD)
        except OSError:
            pass

    def ims_up(self):
        if self.ims_state in ('starting', 'up') or self.disabled:
            return
        why = modem_ready()
        if why:
            log('modem not ready for IMS (%s), waiting' % why)
            self._schedule_retry(15)
            return
        self.ims_state = 'starting'
        self.ims = ImsLink(log, SECRETS)
        self.ims.handler = self
        self.ims.on_down = self._ims_down
        try:
            if not os.path.exists('/run/winglm-ipa-ready'):
                self.guard(True)
                GLib.timeout_add_seconds(180, lambda: self.guard(False) and False)
            self.ims.start()
            self.ims_state = 'up'
        except Exception as e:
            log('IMS start failed: %s' % e)
            self._teardown_ims()
            self._schedule_retry(30)

    def _ims_down(self, why):
        for call in list(set(self.calls.values())):
            self.hangup(call, 'IMS link lost', from_net=True)
        self._teardown_ims()
        self._schedule_retry(15)

    def _teardown_ims(self):
        if self.ims:
            try:
                self.ims.stop()
            except Exception as e:
                log('IMS stop: %s' % e)
        self.ims = None
        self.ims_state = 'idle'

    def _schedule_retry(self, secs):
        if self.retry_src:
            GLib.source_remove(self.retry_src)

        def again():
            self.retry_src = None
            if self.calls_contact and self.ims_state == 'idle':
                self.ims_up()
            return False
        self.ims_state = 'retry' if self.calls_contact else 'idle'
        if self.calls_contact:
            self.retry_src = GLib.timeout_add_seconds(secs, again)
        self.ims_state = 'idle'

    def ims_registered(self):
        return self.ims is not None and self.ims.registered

    def write_status(self):
        try:
            os.makedirs('/run/winglm-volte', exist_ok=True)
            with open('/run/winglm-volte/status.tmp', 'w') as f:
                f.write('calls=%d%sims=%s%supdated=%d%s' % (
                    1 if self.calls_contact else 0, os.linesep,
                    'registered' if self.ims_registered() else
                    ('disabled' if self.disabled else self.ims_state), os.linesep,
                    int(time.time()), os.linesep))
            os.replace('/run/winglm-volte/status.tmp', '/run/winglm-volte/status')
        except OSError:
            pass
        return True

    def calls_registered(self, contact, addr, exp):
        self.calls_contact = (contact, addr)
        if getattr(self, 'gone_src', None):
            GLib.source_remove(self.gone_src)
            self.gone_src = None
        if self.calls_expiry_src:
            GLib.source_remove(self.calls_expiry_src)
        self.calls_expiry_src = GLib.timeout_add_seconds(int(exp or 3600) + 90, self._calls_expired)
        if self.ims_state == 'idle' and not self.retry_src:
            GLib.idle_add(lambda: self.ims_up() and False)

    def _calls_expired(self):
        self.calls_expiry_src = None
        log('GNOME Calls registration expired')
        self.calls_gone()
        return False

    def calls_gone(self):
        # Calls unregisters and registers again from the new address on
        # every network change: only give up IMS if it stays away
        self.calls_contact = None
        if self.retry_src:
            GLib.source_remove(self.retry_src)
            self.retry_src = None
        if getattr(self, 'gone_src', None):
            return

        def later():
            self.gone_src = None
            if not self.calls_contact and not self.calls and self.ims:
                log('GNOME Calls gone: IMS off, calls go over CS')
                self._teardown_ims()
            return False
        self.gone_src = GLib.timeout_add_seconds(20, later)

    # =============================================================== local side (GNOME Calls)
    def _loc_rx(self, fd, cond):
        try:
            data, addr = self.loc.recvfrom(65535)
        except BlockingIOError:
            return True
        if not data.strip():
            return True
        try:
            m = Msg.parse(data)
            if m.is_request:
                self.on_local_request(m, addr)
            else:
                self.on_local_response(m, addr)
        except Exception as e:
            log('local error: %s\n%s' % (e, traceback.format_exc()))
        return True

    def loc_send(self, m, addr):
        self.loc.sendto(m.encode(), addr)

    def on_local_request(self, m, addr):
        meth = m.method
        if meth != 'REGISTER':
            log('calls >>> %s' % m.first)
        if meth == 'REGISTER':
            c = m.get('Contact')
            exp = m.get('Expires') or (re.search(r'expires=(\d+)', c or '') or [None, None])[1]
            log('GNOME Calls REGISTER from %s:%d expires %s' % (addr[0], addr[1], exp))
            gone = exp == '0' or not c or c.strip() == '*'
            # short: Calls has to notice soon when IMS goes away
            grant = 0 if gone else min(int(exp or 3600), CALLS_EXPIRES)
            if not gone and not self.ims_registered():
                # VoLTE not available: the account goes offline in Calls, so
                # it dials over the modem (CS); Calls (patched) registers
                # again every 30 s and comes back online once IMS is up.
                # Calls being here is still what brings IMS up.
                self.loc_send(response(m, 503, 'VoLTE not available', extra=[('Retry-After', '30')]), addr)
                self.calls_registered(uri_of(c), addr, grant)
                return
            r = response(m, 200, to_tag=rnd(6), extra=[('Contact', (c or '') + ';expires=%d' % grant),
                                                       ('Expires', str(grant))])
            self.loc_send(r, addr)
            if gone:
                self.calls_gone()
            else:
                self.calls_registered(uri_of(c), addr, grant)
            return
        if meth == 'OPTIONS':
            self.loc_send(response(m, 200), addr)
            return
        call = self.calls.get(m.call_id)
        if meth == 'INVITE' and not call:
            self.mo_start(m, addr)
            return
        if not call:
            if meth != 'ACK':
                self.loc_send(response(m, 481), addr)
            return
        if meth == 'ACK':
            return
        if meth == 'CANCEL':
            self.loc_send(response(m, 200), addr)
            self.hangup(call, 'calls cancel')
            return
        if meth == 'BYE':
            self.loc_send(response(m, 200), addr)
            self.hangup(call, 'calls bye')
            return
        self.loc_send(response(m, 200), addr)

    def on_local_response(self, m, addr):
        call = self.calls.get(m.call_id)
        log('calls <<< %s (%s)' % (m.first, m.get('CSeq')))
        if not call or m.cseq_method != 'INVITE' or call.dir != 'mt':
            return
        if m.code == 180:
            return
        if 200 <= m.code < 300:
            call.loc.remote_tag = m.tag('To')
            call.loc.remote_target = uri_of(m.get('Contact')) if m.get('Contact') else None
            ack = self._loc_req(call, 'ACK', cseq=call.loc.invite.cseq)
            self.loc_send(ack, call.loc.via)
            ans = SDP.Sdp(m.body)
            call.calls_rtp = ans.port
            call.calls_ip = ans.conn or addr[0]
            if call.state != 'answered':
                call.state = 'answered'
                self.mt_answer(call)
        elif m.code >= 300:
            if call.state not in ('ended',):
                self.mt_reject(call, 486 if m.code in (486, 600, 603) else 480)

    def _loc_req(self, call, method, cseq=None, body='', target=None):
        d = call.loc
        if cseq is None:
            d.cseq += 1
            cseq = d.cseq
        m = Msg('%s %s SIP/2.0' % (method, target or d.remote_target or self.calls_contact[0]))
        m.add('Via', 'SIP/2.0/UDP 127.0.0.1:%d;branch=%s;rport' % (LOCAL_PORT, branch()))
        m.add('Max-Forwards', '70')
        if not d.remote_uri or not d.local_uri:
            # Calls-side dialog never set up (a network BYE on an MO call
            # used to crash here, 2026-11-20): fall back to the contact
            d.remote_uri = d.remote_uri or '<%s>' % (target or d.remote_target or self.calls_contact[0])
            d.local_uri = d.local_uri or '<sip:volte@127.0.0.1>'
        m.add('From', '%s;tag=%s' % (d.local_uri, d.local_tag))
        m.add('To', d.remote_uri + (';tag=%s' % d.remote_tag if d.remote_tag else ''))
        m.add('Call-ID', d.call_id)
        m.add('CSeq', '%d %s' % (cseq, method))
        m.add('Contact', '<sip:volte@127.0.0.1:%d>' % LOCAL_PORT)
        if body:
            m.add('Content-Type', 'application/sdp')
            m.body = body
        return m

    # =============================================================== MO
    def mo_start(self, inv, addr):
        target = uri_of(inv.get('To'))
        number = user_of(target)
        call = Call(self, 'mo')
        call.loc.call_id = inv.call_id
        call.loc.invite = inv
        call.loc.via = addr
        call.loc.remote_tag = inv.tag('From')
        # we are the UAS of this dialog: requests we send (BYE) go back to Calls
        call.loc.local_uri = inv.get('To').split(';tag=')[0]
        call.loc.remote_uri = inv.get('From').split(';tag=')[0]
        call.loc.remote_target = uri_of(inv.get('Contact')) if inv.get('Contact') else uri_of(inv.get('From'))
        self.calls[inv.call_id] = call
        self.loc_send(response(inv, 100), addr)
        if re.sub(r'\D', '', number) == ECHO_TEST:
            offer = SDP.Sdp(inv.body)
            log('echo test call; calls SDP: %s' % inv.body.replace('\r\n', ' | ')[:400])
            call.relay = Relay('127.0.0.1', log)
            call.relay.start_echo()
            self.audio_mode(1)
            call.state = 'connected'
            self.loc_send(response(inv, 200, to_tag=call.loc.local_tag,
                                   extra=[('Contact', '<sip:volte@127.0.0.1:%d>' % LOCAL_PORT)],
                                   body=SDP.local_sdp(call.relay.loc_port)), addr)
            return
        if not self.ims_registered():
            log('MO call but IMS not registered')
            self._loc_final(call, 503)
            return
        offer = SDP.Sdp(inv.body)
        log('calls SDP: %s' % inv.body.replace('\r\n', ' | ')[:600])
        call.calls_rtp = offer.port
        call.calls_ip = offer.conn or addr[0]
        call.relay = self.make_relay()
        n = call.net
        n.call_id = rnd(16) + '@' + self.ims.ue
        self.calls[n.call_id] = call
        ruri = normalize(number, self.ims.domain)
        n.remote_uri = '<%s>' % ruri
        n.local_uri = self.ims.preferred_identity()
        n.route = self.ims.route_set()
        n.remote_target = ruri
        n.cseq = 1
        m = Msg('INVITE %s SIP/2.0' % ruri)
        m.add('Via', 'x')
        m.add('Max-Forwards', '70')
        for r in n.route:
            m.add('Route', r)
        m.add('From', '%s;tag=%s' % (n.local_uri, n.local_tag))
        m.add('To', n.remote_uri)
        m.add('Call-ID', n.call_id)
        m.add('CSeq', '1 INVITE')
        m.add('Contact', '<sip:%s@%s:%d>;+g.3gpp.icsi-ref="urn%%3Aurn-7%%3A3gpp-service.ims.icsi.mmtel";'
              '+sip.instance="%s"' % (self.ims.user, self.ims.ue, self.ims.ps, self.ims.instance))
        m.add('P-Preferred-Identity', n.local_uri)
        m.add('P-Preferred-Service', 'urn:urn-7:3gpp-service.ims.icsi.mmtel')
        m.add('Accept-Contact', '*;+g.3gpp.icsi-ref="urn%3Aurn-7%3A3gpp-service.ims.icsi.mmtel"')
        m.add('P-Access-Network-Info', self.ims.pani)
        m.add('Supported', '100rel,timer')
        m.add('Allow', 'INVITE,ACK,CANCEL,BYE,UPDATE,PRACK,INFO,OPTIONS')
        m.add('Content-Type', 'application/sdp')
        m.body = SDP.net_offer(self.ims.ue, call.relay.net_port, modem=self.modem_media(call))
        n.invite = m
        call.state = 'calling'
        log('MO call to %s' % ruri)
        self.ims.send_request(m, lambda r, c=call: self.mo_response(c, r))

    def mo_response(self, call, r):
        if r is None:
            log('MO INVITE timed out')
            self._loc_final(call, 408)
            self.end(call)
            return
        n = call.net
        if r.code == 100:
            return
        if r.tag('To'):
            n.remote_tag = r.tag('To')
        if r.get('Contact'):
            n.remote_target = uri_of(r.get('Contact'))
        rr = r.getall('Record-Route')
        if rr and r.code < 300:
            routes = []
            for v in rr:
                routes += [x.strip() for x in v.split(',')]
            n.route = list(reversed(routes))
        if r.code < 200:
            if r.body and not call.media_started:
                self._mo_media(call, r.body)
            if '100rel' in r.tokens('Require') and r.get('RSeq'):
                pr = self._net_req(call, 'PRACK')
                pr.add('RAck', '%s %d INVITE' % (r.get('RSeq'), n.invite.cseq))
                self.ims.send_request(pr, lambda x: None)
            if r.code in (180, 183) and call.state == 'calling':
                lr = response(call.loc.invite, 180 if r.code == 180 or call.media_started else 183,
                              to_tag=call.loc.local_tag,
                              extra=[('Contact', '<sip:volte@127.0.0.1:%d>' % LOCAL_PORT)],
                              body=SDP.local_sdp(call.relay.loc_port) if call.media_started else '')
                self.loc_send(lr, call.loc.via)
            return
        if r.code < 300:
            ack = self._net_req(call, 'ACK', cseq=n.invite.cseq)
            self.ims.send_request(ack, None, retrans=False)
            if call.state == 'connected':
                return
            if r.body and not call.media_started:
                self._mo_media(call, r.body)
            call.state = 'connected'
            lr = response(call.loc.invite, 200, to_tag=call.loc.local_tag,
                          extra=[('Contact', '<sip:volte@127.0.0.1:%d>' % LOCAL_PORT)],
                          body=SDP.local_sdp(call.relay.loc_port))
            self.loc_send(lr, call.loc.via)
            log('MO call connected')
            return
        # failure: ACK (same branch as the INVITE)
        ack = Msg('ACK %s SIP/2.0' % n.invite.uri)
        ack.add('Via', n.invite.get('Via'))
        ack.add('Max-Forwards', '70')
        for x in n.route if False else self.ims.route_set():
            ack.add('Route', x)
        ack.add('From', n.invite.get('From'))
        ack.add('To', r.get('To'))
        ack.add('Call-ID', n.call_id)
        ack.add('CSeq', '%d ACK' % n.invite.cseq)
        self.ims.send_request(ack, None, retrans=False)
        log('MO call failed: %s' % r.first)
        self._loc_final(call, r.code if r.code < 700 else 500)
        self.end(call)

    def make_relay(self):
        """modem media (LG MMPF) if the modem engine answers, else AP media"""
        if modemmedia.enabled():
            try:
                modemmedia.engine(log)
                return modemmedia.ModemRelay(self.ims.ue, log, self.ims.pdn.profile)
            except Exception as e:
                log('modem media unavailable (%s): using AP media' % e)
        return Relay(self.ims.ue, log)

    @staticmethod
    def modem_media(call):
        return getattr(call.relay, 'modem', False)

    def _start_media(self, call, sdp, ch):
        pt, name, fmtp, oa = ch
        rate = 16000 if name == 'AMR-WB' else 8000
        self.ims.pdn.route(sdp.conn)
        try:
            call.relay.start(sdp.conn, sdp.port, pt, name, call.calls_rtp, self._mode(fmtp, name), call.calls_ip,
                             fmtp=fmtp, oa=oa, dtmf_pt=sdp.dtmf_pt(rate), rtcp_port=sdp.rtcp_port())
        except Exception as e:
            log('media start failed: %s' % e)
        self.audio_mode(1)
        call.media_started = True

    def _mo_media(self, call, body):
        ans = SDP.Sdp(body)
        ch = ans.pick_amr(be_ok=self.modem_media(call))
        if not ch or not ans.port:
            log('network SDP without usable AMR: %s' % body.replace('\r\n', ' | ')[:400])
            return
        self._start_media(call, ans, ch)

    def _mode(self, fmtp, name):
        m = re.search(r'mode-set=([\d,]+)', fmtp or '')
        top = 8 if name == 'AMR-WB' else 7
        want = 2 if name == 'AMR-WB' else 7
        if m:
            modes = [int(x) for x in m.group(1).split(',') if x.isdigit()]
            ok = [x for x in modes if x <= top]
            if ok:
                return want if want in ok else max(ok)
        return want

    def _loc_final(self, call, code):
        self.loc_send(response(call.loc.invite, code, to_tag=call.loc.local_tag), call.loc.via)

    # =============================================================== network requests
    def on_request(self, m, via):
        call = self.calls.get(m.call_id)
        meth = m.method
        if meth == 'INVITE' and not call:
            self.mt_start(m, via)
            return
        if not call:
            if meth == 'NOTIFY':
                self.ims.send_response(response(m, 200), via)
            elif meth != 'ACK':
                self.ims.send_response(response(m, 481), via)
            return
        if meth == 'ACK':
            return
        if meth == 'PRACK':
            self.ims.send_response(response(m, 200), via)
            if call.pending_answer:
                f, call.pending_answer = call.pending_answer, None
                f()
            return
        if meth == 'UPDATE':
            body = ''
            if m.body and call.net_choice:
                off = SDP.Sdp(m.body)
                pre = self._precond_lines(off, met=True) if off.has_precondition() else None
                body = SDP.net_answer(self.ims.ue, call.relay.net_port, off, call.net_choice, ver=3, precond=pre)
            self.ims.send_response(response(m, 200, extra=[('Contact', self._net_contact())], body=body), via)
            if call.dir == 'mt' and call.state == 'precond':
                self.mt_ring(call)
            return
        if meth in ('BYE', 'CANCEL'):
            self.ims.send_response(response(m, 200), via)
            if meth == 'CANCEL' and call.dir == 'mt' and call.state != 'answered':
                self.ims.send_response(response(call.net.invite, 487, to_tag=call.net.local_tag), call.net.via)
            self.hangup(call, 'network ' + meth.lower(), from_net=True)
            return
        if meth == 'INVITE':        # re-INVITE: answer with the same media
            off = SDP.Sdp(m.body) if m.body else None
            body = SDP.net_answer(self.ims.ue, call.relay.net_port, off, call.net_choice, ver=4) if off else ''
            self.ims.send_response(response(m, 200, extra=[('Contact', self._net_contact())], body=body), via)
            return
        self.ims.send_response(response(m, 200), via)

    def on_stray_response(self, m):
        pass

    def _net_contact(self):
        return ('<sip:%s@%s:%d>;+g.3gpp.icsi-ref="urn%%3Aurn-7%%3A3gpp-service.ims.icsi.mmtel"'
                % (self.ims.user, self.ims.ue, self.ims.ps))

    def _net_req(self, call, method, cseq=None, body=''):
        n = call.net
        if cseq is None:
            n.cseq += 1
            cseq = n.cseq
        m = Msg('%s %s SIP/2.0' % (method, n.remote_target))
        m.add('Via', 'x')
        m.add('Max-Forwards', '70')
        for r in n.route:
            m.add('Route', r)
        if call.dir == 'mo':
            m.add('From', '%s;tag=%s' % (n.local_uri, n.local_tag))
            m.add('To', '%s;tag=%s' % (n.remote_uri, n.remote_tag) if n.remote_tag else n.remote_uri)
        else:
            m.add('From', '%s;tag=%s' % (n.local_uri, n.local_tag))
            m.add('To', '%s;tag=%s' % (n.remote_uri, n.remote_tag))
        m.add('Call-ID', n.call_id)
        m.add('CSeq', '%d %s' % (cseq, method))
        if method in ('INVITE', 'UPDATE'):
            m.add('Contact', self._net_contact())
        if body:
            m.add('Content-Type', 'application/sdp')
            m.body = body
        return m

    # =============================================================== MT
    def mt_start(self, inv, via):
        call = Call(self, 'mt')
        n = call.net
        n.call_id = inv.call_id
        n.invite = inv
        n.via = via
        n.remote_tag = inv.tag('From')
        n.remote_uri = inv.get('From').split(';tag=')[0]
        n.local_uri = inv.get('To').split(';tag=')[0]
        n.remote_target = uri_of(inv.get('Contact'))
        routes = []
        for v in inv.getall('Record-Route'):
            routes += [x.strip() for x in v.split(',')]
        n.route = routes
        n.cseq = 0
        self.calls[n.call_id] = call
        self.ims.send_response(response(inv, 100), via)
        log('MT INVITE: Require=%s Supported=%s' % (inv.get('Require'), inv.get('Supported')))
        log('MT SDP: %s' % inv.body.replace('\r\n', ' | ')[:700])
        if not self.calls_contact:
            log('no GNOME Calls registered: rejecting')
            self.mt_reject(call, 480)
            return
        if not inv.body:
            self.mt_reject(call, 488)
            return
        off = SDP.Sdp(inv.body)
        call.relay = self.make_relay()
        ch = off.pick_amr(be_ok=self.modem_media(call))
        if not ch:
            log('no usable AMR in the offer')
            self.mt_reject(call, 488)
            return
        call.net_offer = off
        call.net_choice = ch
        caller = inv.get('P-Asserted-Identity') or inv.get('From')
        call.caller = user_of(uri_of(caller.split(',')[0]))
        need_pre = 'precondition' in inv.tokens('Require') or \
            (off.mandatory_precondition() and 'precondition' in inv.tokens('Supported'))
        if need_pre:
            call.state = 'precond'
            pre = self._precond_lines(off, met=False)
            body = SDP.net_answer(self.ims.ue, call.relay.net_port, off, ch, ver=1, precond=pre)
            self._mt_provisional(call, 183, body, reliable=True)
            # if the network never sends UPDATE, ring anyway
            GLib.timeout_add_seconds(4, lambda c=call: (c.state == 'precond' and self.mt_ring(c)) and False)
        else:
            self.mt_ring(call)

    def _precond_lines(self, off, met):
        st = 'sendrecv' if met else 'none'
        return ['a=curr:qos local %s' % st, 'a=curr:qos remote %s' % st,
                'a=des:qos mandatory local sendrecv', 'a=des:qos mandatory remote sendrecv'] + \
               ([] if met else ['a=conf:qos remote sendrecv'])

    def _mt_provisional(self, call, code, body, reliable):
        inv = call.net.invite
        extra = [('Contact', self._net_contact())]
        if reliable:
            call.rseq += 1
            extra += [('Require', '100rel' + (',precondition' if body and 'curr:qos' in body else '')),
                      ('RSeq', str(call.rseq))]
        if body:
            call.answer_sent = True
        r = response(inv, code, to_tag=call.net.local_tag, extra=extra, body=body)
        self.ims.send_response(r, call.net.via)

    def mt_ring(self, call):
        if call.state in ('ringing', 'answered', 'ended'):
            return
        call.state = 'ringing'
        inv = call.net.invite
        reliable = '100rel' in inv.tokens('Require')
        self._mt_provisional(call, 180, '', reliable)
        # ring GNOME Calls
        d = call.loc
        d.call_id = rnd(16) + '@127.0.0.1'
        self.calls[d.call_id] = call
        d.local_uri = '<sip:%s@127.0.0.1>' % (call.caller or 'unknown')
        d.remote_uri = '<%s>' % self.calls_contact[0]
        d.remote_target = self.calls_contact[0]
        d.cseq = 1
        m = self._loc_req(call, 'INVITE', cseq=1, body=SDP.local_sdp(call.relay.loc_port))
        d.invite = m
        d.via = self.calls_contact[1]
        self.loc_send(m, self.calls_contact[1])
        log('MT call from %s ringing in Calls' % call.caller)

    def mt_answer(self, call):
        off, ch = call.net_offer, call.net_choice
        self._start_media(call, off, ch)
        pre =self._precond_lines(off, met=True) if call.net_offer.has_precondition() else None
        body = '' if call.rseq and call.state == 'answered' and False else \
            SDP.net_answer(self.ims.ue, call.relay.net_port, off, ch, ver=2, precond=pre)
        if call.rseq:
            body = ''           # SDP answer already sent in the reliable 183
        r = response(call.net.invite, 200, to_tag=call.net.local_tag,
                     extra=[('Contact', self._net_contact())], body=body)
        self.ims.send_response(r, call.net.via)
        log('MT call answered')

    def mt_reject(self, call, code):
        r = response(call.net.invite, code, to_tag=call.net.local_tag)
        self.ims.send_response(r, call.net.via)
        self.end(call)

    # =============================================================== teardown
    def hangup(self, call, why, from_net=False):
        if call.state == 'ended':
            return
        log('hangup (%s)' % why)
        try:
            self._hangup_signal(call, from_net)
        except Exception as e:
            log('hangup: %s' % e)
        if call.state != 'ended':
            self.end(call)

    def _hangup_signal(self, call, from_net):
        if not from_net:
            if call.dir == 'mo' and call.state == 'calling':
                n = call.net
                c = Msg('CANCEL %s SIP/2.0' % n.invite.uri)
                c.add('Via', n.invite.get('Via'))
                c.add('Max-Forwards', '70')
                for r in self.ims.route_set():
                    c.add('Route', r)
                c.add('From', n.invite.get('From'))
                c.add('To', n.invite.get('To'))
                c.add('Call-ID', n.call_id)
                c.add('CSeq', '%d CANCEL' % n.invite.cseq)
                self.ims.send_request(c, lambda r: None, retrans=False)
            elif call.dir == 'mt' and call.state != 'answered':
                self.mt_reject(call, 486)
                return
            elif call.net.remote_tag:
                self.ims.send_request(self._net_req(call, 'BYE'), lambda r: None)
        else:
            if call.loc.call_id and call.loc.invite:
                if call.dir == 'mt' and call.state != 'answered':
                    c = self._loc_req(call, 'CANCEL', cseq=call.loc.invite.cseq)
                    c.set('Via', call.loc.invite.get('Via'))
                    self.loc_send(c, call.loc.via)
                elif call.dir == 'mo' and call.state == 'calling':
                    self._loc_final(call, 487)
                else:
                    self.loc_send(self._loc_req(call, 'BYE'), call.loc.via)

    def end(self, call):
        had_media = call.relay is not None and (call.media_started or call.state == 'connected')
        call.state = 'ended'
        if call.relay:
            call.relay.stop()
        for k in [k for k, v in self.calls.items() if v is call]:
            del self.calls[k]
        if had_media and not self.calls:
            self.audio_mode(0)

    def audio_mode(self, mode):
        """callaudiod (user session) in call mode: VoiceCall UCM verb, earpiece
        and the Calls speaker button. GNOME Calls only does this for modem
        calls."""
        import pwd
        import subprocess
        try:
            greeter = pwd.getpwnam('greetd').pw_uid
            pid = []
            # callaudiod may not run (PulseAudio restarted): any process of
            # the session gives its bus, D-Bus activation starts callaudiod
            for name in ('callaudiod', 'gnome-calls'):
                pid = [p for p in subprocess.run(['pgrep', '-x', name], capture_output=True,
                                                 text=True).stdout.split()
                       if os.stat('/proc/' + p).st_uid not in (0, greeter)]
                if pid:
                    break
            if not pid:
                log('callaudiod mode %d: no session found' % mode)
                return
            st = os.stat('/proc/' + pid[0])
            env = dict(x.split('=', 1) for x in open('/proc/%s/environ' % pid[0]).read().split('\0') if '=' in x)
            env = {k: env[k] for k in ('DBUS_SESSION_BUS_ADDRESS', 'XDG_RUNTIME_DIR', 'HOME', 'PATH') if k in env}
            # don't wait: the profile switch takes a while and the call must go on
            subprocess.Popen(['gdbus', 'call', '--session', '--timeout', '10', '--dest',
                              'org.mobian_project.CallAudio', '--object-path', '/org/mobian_project/CallAudio',
                              '--method', 'org.mobian_project.CallAudio.SelectMode', str(mode)],
                             env=env, user=st.st_uid, group=st.st_gid, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            log('callaudiod mode %d requested' % mode)
        except Exception as e:
            log('callaudiod mode %d failed: %s' % (mode, e))


def main():
    mgr = Manager()
    loop = GLib.MainLoop()

    def stop(*a):
        log('stopping')
        try:
            mgr._teardown_ims()
            mgr.fallback_route(False)
        finally:
            loop.quit()
        return False

    for sig in (signal.SIGTERM, signal.SIGINT):
        if GLibUnix is not None:
            GLibUnix.signal_add(GLib.PRIORITY_HIGH, sig, stop)
        else:
            GLib.unix_signal_add(GLib.PRIORITY_HIGH, sig, stop)
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        GLib.timeout_add_seconds(int(sys.argv[1]), stop)
    log('waiting for GNOME Calls on 127.0.0.1:%d' % LOCAL_PORT)
    loop.run()


if __name__ == '__main__':
    main()
