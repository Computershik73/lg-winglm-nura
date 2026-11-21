"""IMS link: IMS PDN, ISIM AKA, IPsec SAs, SIP transports (UDP/TCP over
ESP) and registration with refresh."""
import base64
import hashlib
import os
import random
import re
import socket
import struct
import time

from gi.repository import GLib

from ipadata import Ipa, Pdn, modem_ids, lte_cell, run, ims_profile
from uimtool import Uim, nai
from sipmsg import Msg, branch, rnd, params, response

DOMAIN_RE = re.compile(r'^[a-z0-9.-]+$')
MTU_SAFE = 1250          # P-CSCF drops fragmented ESP: bigger requests go over TCP


def _setting(name, default):
    """test knobs in /etc/winglm-volte/: expires (requested registration
    time; MegaFon grants 7200 s, Min-Expires 3600) and refresh (seconds
    between re-REGISTERs instead of half the registration time)"""
    try:
        return int(open('/etc/winglm-volte/' + name).read().strip())
    except (OSError, ValueError):
        return default


EXPIRES = _setting('expires', 600000)
REFRESH = _setting('refresh', 0)


def isim_aid():
    out = run('qmicli -d qrtr://0 --uim-get-card-status').stdout.splitlines()
    for i, l in enumerate(out):
        if 'Application type' in l and 'isim' in l:
            for k in range(i, min(i + 12, len(out))):
                if 'Application ID' in out[k]:
                    v = out[k].split('Application ID:')[1].strip().strip("'")
                    if not v:
                        v = out[k + 1].strip().strip("'")
                    return bytes.fromhex(v.replace(':', ''))
    raise RuntimeError('no ISIM application')


class Isim:
    def __init__(self):
        self.u = Uim()
        self.ch = self.u.open(isim_aid())
        r, _ = self.u.read_binary(self.ch, 0x6F02)
        self.impi = nai(r)
        r, _ = self.u.read_binary(self.ch, 0x6F03)
        self.domain = nai(r)
        r, _ = self.u.read_record(self.ch, 0x6F04, 1)
        self.impu = nai(r)

    def authenticate(self, rand, autn):
        cmd = bytes([0x00, 0x88, 0x00, 0x81, 34, 16]) + rand + bytes([16]) + autn + b'\x00'
        r, sw = self.u.apdu(self.ch, cmd)
        if sw >> 8 == 0x61:
            r, sw = self.u.get_response(self.ch, sw)
        if sw != 0x9000:
            raise RuntimeError('AUTHENTICATE sw %04x' % sw)
        if r[0] == 0xDB:
            i, out = 1, []
            for _ in range(3):
                out.append(r[i + 1:i + 1 + r[i]])
                i += 1 + r[i]
            return 'ok', out
        if r[0] == 0xDC:
            return 'sync', [r[2:2 + r[1]]]
        raise RuntimeError('AUTHENTICATE: unexpected %s' % r[:2].hex())

    def close(self):
        try:
            self.u.close(self.ch)
        except Exception:
            pass


class TcpConn:
    def __init__(self, sock, addr, link):
        self.sock, self.addr, self.link = sock, addr, link
        self.buf = b''
        sock.setblocking(False)
        self.watch = GLib.io_add_watch(sock.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self._rx)

    def _rx(self, fd, cond):
        try:
            data = self.sock.recv(65536)
        except BlockingIOError:
            return True
        except OSError:
            data = b''
        if not data:
            self.link.log('tcp %s:%d closed' % self.addr)
            self.close()
            return False
        self.buf += data
        while True:
            hdr_end = self.buf.find(b'\r\n\r\n')
            if hdr_end < 0:
                break
            head = self.buf[:hdr_end].decode(errors='replace')
            m = re.search(r'(?im)^(?:content-length|l)\s*:\s*(\d+)', head)
            ln = int(m.group(1)) if m else 0
            if len(self.buf) < hdr_end + 4 + ln:
                break
            raw, self.buf = self.buf[:hdr_end + 4 + ln], self.buf[hdr_end + 4 + ln:]
            if raw.strip():
                self.link.on_message(Msg.parse(raw), ('tcp', self, self.addr))
        return True

    def send(self, data):
        self.sock.setblocking(True)
        self.sock.sendall(data)
        self.sock.setblocking(False)

    def close(self, reset=False):
        if self.watch:
            GLib.source_remove(self.watch)
            self.watch = None
        try:
            if reset:
                self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
            self.sock.close()
        except OSError:
            pass
        if self in self.link.tcp_conns:
            self.link.tcp_conns.remove(self)
        if self.link.tcp_client is self:
            self.link.tcp_client = None


class ImsLink:
    """owns the IMS PDN and the registration; hands SIP requests and
    responses to self.handler (the call layer)"""

    def __init__(self, log, secrets):
        self.log = log
        self.secrets = secrets
        self.handler = None
        self.on_down = None          # callback(reason): link unusable
        self.dead = False
        self.reg_failures = 0
        self.registered = False
        self.reg_cbs = []
        self.pending = {}            # (branch, method) -> callback(resp)
        self.answered = set()        # transactions with a response (no retransmissions)
        self.tcp_conns = []
        self.tcp_client = None
        self.socks = []
        self.watches = []
        self.refresh_src = None
        self.refreshing = False      # a re-REGISTER is outstanding
        self.expires = EXPIRES
        self.ipa = None
        self.pdn = None
        self.isim = None

    # ------------------------------------------------------------ bring-up
    def start(self):
        run('ip xfrm policy flush; ip xfrm state flush')
        self.ipa = Ipa(self.log)
        self.pdn = Pdn(2, profile=ims_profile(self.log), log=self.log)
        st = self.pdn.start()
        self.watches.append(GLib.io_add_watch(self.pdn.wds.sock.fileno(), GLib.IO_IN, self._wds_ind))
        if not st.get('pcscf'):
            raise RuntimeError('IMS PDN without P-CSCF')
        self.ue = st['ip']
        self.pcscfs = st['pcscf']
        self.p = self.pcscfs[0]
        self.pdn.route(self.p)
        self.log('IMS PDN up: %s, P-CSCF %s' % (self.ue, ', '.join(self.pcscfs)))
        self.isim = Isim()
        self.user = self.isim.impi.split('@')[0]
        self.secrets.append(self.user)
        imei = modem_ids()
        self.secrets += [imei, '%s-%s-0' % (imei[:8], imei[8:14])]
        self.instance = '<urn:gsma:imei:%s-%s-0>' % (imei[:8], imei[8:14])
        # right after a restart the modem may not answer the NAS query yet
        plmn = tac = eci = None
        for _ in range(3):
            plmn, tac, eci = lte_cell()
            if plmn and tac is not None and eci is not None:
                break
            time.sleep(1)
        if plmn and tac is not None and eci is not None:
            self.pani = '3GPP-E-UTRAN-FDD; utran-cell-id-3gpp=%s%04X%07X' % (plmn, tac, eci)
        else:
            self.log('cell location unknown: P-Access-Network-Info without the cell id')
            self.pani = '3GPP-E-UTRAN-FDD'
        self.domain = self.isim.domain
        self.cseq = 0
        self.pc = random.randint(15000, 32000) * 2 + 1
        self.ps = self.pc + 1
        self.unprot = self._udp(5060)
        self.udp_pc = self._udp(self.pc)
        self.udp_ps = self._udp(self.ps)
        lst = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        lst.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        lst.bind((self.ue, self.ps))
        lst.listen(4)
        lst.setblocking(False)
        self.socks.append(lst)
        self.watches.append(GLib.io_add_watch(lst.fileno(), GLib.IO_IN, self._accept, lst))
        self.register_initial()

    def _wds_ind(self, fd, cond):
        try:
            pkt, _ = self.pdn.wds.sock.recvfrom(65536)
        except OSError:
            return True
        if len(pkt) >= 7 and pkt[0] == 4:
            mid = struct.unpack_from('<H', pkt, 3)[0]
            body = pkt[7:]
            if mid == 0x22 and len(body) >= 5 and body[0] == 1 and body[3] == 1:
                self.down('IMS PDN disconnected')
        return True

    def down(self, why):
        if self.dead:
            return
        self.dead = True
        self.registered = False
        self.log('IMS link down: %s' % why)
        if self.on_down:
            GLib.idle_add(lambda: self.on_down(why) and False)

    def _udp(self, port):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.bind((self.ue, port))
        s.setblocking(False)
        self.socks.append(s)
        self.watches.append(GLib.io_add_watch(s.fileno(), GLib.IO_IN, self._udp_rx, s))
        return s

    def _udp_rx(self, fd, cond, s):
        try:
            data, addr = s.recvfrom(65535)
        except BlockingIOError:
            return True
        if data.strip():
            self.on_message(Msg.parse(data), ('udp', s, addr))
        return True

    def _accept(self, fd, cond, lst):
        try:
            c, addr = lst.accept()
        except BlockingIOError:
            return True
        self.log('tcp from %s:%d' % addr)
        self.tcp_conns.append(TcpConn(c, addr, self))
        return True

    def stop(self):
        if self.refresh_src:
            GLib.source_remove(self.refresh_src)
            self.refresh_src = None
        self.reg_stopping = True
        if self.registered and not self.dead:
            try:
                self._send_register(expires=0, cb=None)
            except Exception as e:
                self.log('de-register failed: %s' % e)
            # let it go out
            end = time.time() + 1.5
            ctx = GLib.MainContext.default()
            while time.time() < end:
                ctx.iteration(False)
                time.sleep(0.05)
        for w in self.watches:
            GLib.source_remove(w)
        for c in list(self.tcp_conns):
            c.close()
        if self.tcp_client:
            self.tcp_client.close()
        for s in self.socks:
            s.close()
        run('ip xfrm policy flush; ip xfrm state flush')
        if self.isim:
            self.isim.close()
        if self.pdn:
            self.pdn.stop()

    # ------------------------------------------------------------ sending
    @staticmethod
    def _new_spis():
        c = random.randint(0x10000, 0x7FFFFFF0)
        return c, c + 1

    def sec_client(self):
        return ', '.join('ipsec-3gpp;alg=hmac-sha-1-96;ealg=%s;prot=esp;mod=trans;spi-c=%d;spi-s=%d;'
                         'port-c=%d;port-s=%d' % (e, self.spi_c, self.spi_s, self.pc, self.ps)
                         for e in ('null', 'aes-cbc'))

    def contact(self, expires=None):
        c = ('<sip:%s@%s:%d>;+sip.instance="%s";+g.3gpp.icsi-ref="urn%%3Aurn-7%%3A3gpp-service.ims.icsi.mmtel";'
             'audio' % (self.user, self.ue, self.ps, self.instance))
        if expires is not None:
            c += ';expires=%d' % expires
        return c

    def via(self, transport):
        return 'SIP/2.0/%s %s:%d;branch=%s;rport' % (transport, self.ue, self.pc, branch())

    def send_request(self, msg, cb=None, retrans=True):
        """protected request to the P-CSCF; picks UDP or TCP by size;
        cb(resp) for every response"""
        size = len(msg.encode()) + 60
        transport = 'TCP' if size > MTU_SAFE else 'UDP'
        v = msg.get('Via')
        if not v or v in ('x', 'placeholder'):
            msg.remove('Via')
            msg.add('Via', self.via(transport), top=True)
        else:                       # CANCEL / non-2xx ACK keep the INVITE's branch
            msg.set('Via', re.sub(r'SIP/2.0/\w+', 'SIP/2.0/' + transport, v))
        b = msg.top_branch
        key = (b, msg.method)
        if cb:
            self.pending[key] = cb
        data = msg.encode()
        self.log('>>> %s (%s %d bytes)' % (msg.first, transport, len(data)))
        if transport == 'TCP':
            self._tcp_send(data)
            if cb and msg.method != 'ACK':
                # Timer B/F: no answer at all within 32 s = transaction failed
                def timeout(key=key):
                    if key in self.pending and key not in self.answered:
                        c = self.pending.pop(key)
                        c(None)
                    return False
                GLib.timeout_add_seconds(32, timeout)
        else:
            self.udp_pc.sendto(data, (self.p, self.psp))
            if retrans and msg.method not in ('ACK',):
                self._retransmit(key, data, 0.5, time.time())
        return b

    def _retransmit(self, b, data, interval, t0):
        def again():
            if b not in self.pending or b in self.answered:
                return False
            if time.time() - t0 > 16:
                cb = self.pending.pop(b, None)
                if cb:
                    cb(None)
                return False
            self.udp_pc.sendto(data, (self.p, self.psp))
            self._retransmit(b, data, min(interval * 2, 4), t0)
            return False
        GLib.timeout_add(int(interval * 1000), again)

    def _tcp_send(self, data, retry=True):
        if not self.tcp_client:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind((self.ue, self.pc))
            s.settimeout(5)
            s.connect((self.p, self.psp))
            self.tcp_client = TcpConn(s, (self.p, self.psp), self)
            self.tcp_conns.append(self.tcp_client)
            self.log('tcp to %s:%d connected' % (self.p, self.psp))
        try:
            self.tcp_client.send(data)
        except OSError as e:
            # the P-CSCF dropped an idle connection without us noticing
            if self.tcp_client:
                self.tcp_client.close()
            if not retry:
                raise
            self.log('tcp send failed (%s): reconnecting' % e)
            self._tcp_send(data, retry=False)

    def send_response(self, resp, via):
        data = resp.encode()
        kind, s, addr = via
        self.log('>>> %s for %s (%s %d bytes)' % (resp.first, resp.get('CSeq'), kind.upper(), len(data)))
        if kind == 'tcp':
            s.send(data)
        else:
            if len(data) + 60 > MTU_SAFE:
                self.log('warning: big response over UDP (%d bytes), may be dropped' % len(data))
            s.sendto(data, addr)

    # ------------------------------------------------------------ receiving
    def on_message(self, m, via):
        try:
            if m.is_request:
                self.log('<<< %s' % m.first)
                if m.method == 'OPTIONS':
                    self.send_response(response(m, 200), via)
                elif self.handler:
                    self.handler.on_request(m, via)
                else:
                    self.send_response(response(m, 480), via)
            else:
                self.log('<<< %s (%s)' % (m.first, m.get('CSeq')))
                b = (m.top_branch, m.cseq_method)
                cb = self.pending.get(b)
                if cb:
                    if m.code >= 200 and m.cseq_method != 'INVITE':
                        self.pending.pop(b, None)
                    self.answered.add(b)
                    cb(m)
                elif self.handler:
                    self.handler.on_stray_response(m)
        except Exception as e:
            import traceback
            self.log('error handling message: %s\n%s' % (e, traceback.format_exc()))

    # ------------------------------------------------------------ registration
    def _register_msg(self, expires, authz, verify, full):
        self.cseq += 1
        uri = 'sip:' + self.domain
        m = Msg('REGISTER %s SIP/2.0' % uri)
        m.add('Via', 'placeholder')
        m.add('Max-Forwards', '70')
        m.add('From', '<%s>;tag=%s' % (self.isim.impu, self.ftag))
        m.add('To', '<%s>' % self.isim.impu)
        m.add('Call-ID', self.call_id)
        m.add('CSeq', '%d REGISTER' % self.cseq)
        m.add('Contact', self.contact(expires))
        m.add('Expires', str(expires))
        m.add('Supported', 'path,sec-agree')
        m.add('Require', 'sec-agree')
        m.add('Proxy-Require', 'sec-agree')
        if full:
            m.add('Allow', 'INVITE,ACK,CANCEL,BYE,UPDATE,PRACK,MESSAGE,OPTIONS,NOTIFY')
            m.add('P-Access-Network-Info', self.pani)
            m.add('Security-Client', self.sec_client())
        if verify:
            m.add('Security-Verify', verify)
        m.add('Authorization', authz or 'Digest username="%s",realm="%s",uri="%s",nonce="",response=""'
              % (self.isim.impi, self.domain, uri))
        return m

    def register_initial(self):
        """a new registration: new Call-ID, From tag and SPIs (re-using the
        old Call-ID with CSeq 1 is answered 400)"""
        self.registered = False
        self.call_id = rnd(16) + '@' + self.ue
        self.ftag = rnd(8)
        self.spi_c, self.spi_s = self._new_spis()
        m = self._register_msg(self.expires, None, None, True)
        m.set('Via', 'SIP/2.0/UDP %s:5060;branch=%s;rport' % (self.ue, branch()))
        key = (m.top_branch, 'REGISTER')
        self.pending[key] = self._on_401
        self.log('>>> %s (unprotected)' % m.first)
        data = m.encode()
        self.unprot.sendto(data, (self.p, 5060))

        def again(n=[0]):
            if key not in self.pending or key in self.answered or self.dead:
                return False
            n[0] += 1
            if n[0] > 5:
                self.pending.pop(key, None)
                self.down('no answer to REGISTER from %s' % self.p)
                return False
            self.unprot.sendto(data, (self.p, 5060))
            return True
        GLib.timeout_add_seconds(2, again)

    def _on_401(self, r):
        if r is None or r.code < 200:
            return
        if r.code == 423 and (r.get('Min-Expires') or '').isdigit() and int(r.get('Min-Expires')) > self.expires:
            self.expires = int(r.get('Min-Expires'))
            self.log('registration interval raised to %d s (Min-Expires)' % self.expires)
            self.register_initial()
            return
        if r.code != 401:
            self.down('initial REGISTER answered %d' % r.code)
            return
        self.chal = r.get('WWW-Authenticate')
        srv = r.getall('Security-Server')
        offers = []
        for line in srv:
            offers += [o.strip() for o in line.split(',') if o.strip()]
        self.verify = ', '.join(offers)
        nonce = base64.b64decode(params(self.chal)['nonce'])
        kind, vals = self.isim.authenticate(nonce[:16], nonce[16:32])
        if kind != 'ok':
            self.down('ISIM synchronisation failure')
            return
        self.res, ck, ik = vals
        self.nc = 1
        best = sorted(offers, key=lambda o: -float(params(o).get('q', '0')))[0]
        self._ipsec(best, ck, ik)
        authz = self._digest('REGISTER', 'sip:' + self.domain)
        m = self._register_msg(self.expires, authz, self.verify, True)
        self.send_request(m, self._on_reg)

    def _digest(self, method, uri):
        p = params(self.chal)
        ha1 = hashlib.md5(('%s:%s:' % (self.isim.impi, p['realm'])).encode() + self.res).hexdigest()
        ha2 = hashlib.md5(('%s:%s' % (method, uri)).encode()).hexdigest()
        a = 'Digest username="%s",realm="%s",uri="%s",nonce="%s",algorithm=AKAv1-MD5' % (
            self.isim.impi, p['realm'], uri, p['nonce'])
        if 'qop' in p:
            cn = rnd(16)
            resp = hashlib.md5(('%s:%s:%08x:%s:auth:%s' % (ha1, p['nonce'], self.nc, cn, ha2)).encode()).hexdigest()
            a += ',qop=auth,nc=%08x,cnonce="%s"' % (self.nc, cn)
            self.nc += 1
        else:
            resp = hashlib.md5(('%s:%s:%s' % (ha1, p['nonce'], ha2)).encode()).hexdigest()
        a += ',response="%s"' % resp
        if 'opaque' in p:
            a += ',opaque="%s"' % p['opaque']
        return a

    def _ipsec(self, srv, ck, ik):
        """SAs for our spi_c/spi_s and the P-CSCF's offer srv (replaces all)"""
        s = params(srv)
        alg, ealg = s['alg'], s.get('ealg', 'null')
        spi_cp, spi_sp = int(s['spi-c']), int(s['spi-s'])
        old_psp = getattr(self, 'psp', None)
        self.pcp, self.psp = int(s['port-c']), int(s['port-s'])
        if alg == 'hmac-sha-1-96':
            auth = "auth-trunc 'hmac(sha1)' 0x%s 96" % (ik + b'\0' * 4).hex()
        else:
            auth = "auth-trunc 'hmac(md5)' 0x%s 96" % ik.hex()
        enc = "enc 'cbc(aes)' 0x%s" % ck.hex() if ealg == 'aes-cbc' else "enc 'ecb(cipher_null)' ''"
        U, P = self.ue, self.p
        # TCP connections belong to the old SAs: reset them (no TIME_WAIT, so
        # the protected client port can connect again right away)
        for c in list(self.tcp_conns):
            c.close(reset=True)
        run('ip xfrm policy flush; ip xfrm state flush')
        cmds = ['ip xfrm state add src %s dst %s proto esp spi %d mode transport %s %s' % (a, b, spi, auth, enc)
                for a, b, spi in ((U, P, spi_sp), (U, P, spi_cp), (P, U, self.spi_c), (P, U, self.spi_s))]
        for proto in ('udp', 'tcp'):
            cmds += ['ip xfrm policy add src %s/32 dst %s/32 sport %d dport %d proto %s dir out '
                     'tmpl src %s dst %s proto esp spi %d mode transport' % (U, P, sp, dp, proto, U, P, spi)
                     for sp, dp, spi in ((self.pc, self.psp, spi_sp), (self.ps, self.pcp, spi_cp))]
        for c in cmds:
            r = run(c)
            if r.returncode:
                raise RuntimeError('xfrm: %s' % (r.stdout + r.stderr).strip())
        self.log('IPsec: %s/%s, P-CSCF ports %d/%d%s' % (alg, ealg, self.pcp, self.psp,
                                                        '' if old_psp in (None, self.psp) else ' (was %d)' % old_psp))

    def _on_reg(self, r):
        if getattr(self, 'reg_stopping', False):
            return
        if r is None:
            self.down('REGISTER timed out')
            return
        if r.code < 200:
            return
        if r.code == 401:
            if self.refreshing:
                # the network re-authenticates (MegaFon: every 2 h)
                self._rechallenge(r)
                return
            self.reg_failures += 1
            if self.reg_failures > 3:
                self.down('repeated 401')
                return
            self.log('re-challenged: new registration')
            self.register_initial()
            return
        if r.code != 200:
            self.down('REGISTER failed %d' % r.code)
            return
        self.reg_failures = 0
        self.refreshing = False
        self.rechallenges = 0
        exp = 3600
        for c in r.getall('Contact'):
            m = re.search(r'expires=(\d+)', c)
            if m and self.user in c:
                exp = int(m.group(1))
        if r.get('Expires'):
            exp = min(exp, int(r.get('Expires')))
        if exp == 0:
            self.registered = False
            return
        self.service_route = r.getall('Service-Route')
        self.assoc = [x.strip() for v in r.getall('P-Associated-URI') for x in v.split(',')]
        self.registered = True
        self.log('IMS registered for %d s' % exp)
        if self.refresh_src:
            GLib.source_remove(self.refresh_src)
        self.refresh_src = GLib.timeout_add_seconds(REFRESH or max(60, exp // 2), self._refresh)
        for cb in self.reg_cbs:
            cb(True)

    def _refresh(self):
        """re-REGISTER inside the current SAs: small, over UDP, no
        Security-Client.  (MegaFon's P-CSCF does not answer a re-REGISTER that
        offers new SPIs, nor an unprotected REGISTER while SAs exist.)"""
        self.refresh_src = None
        self.refreshing = True
        try:
            self._send_register(self.expires, self._on_reg)
        except Exception as e:
            self.down('re-REGISTER not sent: %s' % e)
        return False

    def _rechallenge(self, r):
        """401 to a re-REGISTER: answer the new AKA challenge inside the same
        registration (same Call-ID, next CSeq).  New SAs only if the 401
        offers them (Security-Server); otherwise the current SAs stay.
        (Answering with a new unprotected registration got 400.)"""
        self.rechallenges = getattr(self, 'rechallenges', 0) + 1
        if self.rechallenges > 2:
            self.down('repeated 401 to re-REGISTER')
            return
        offers = []
        for line in r.getall('Security-Server'):
            offers += [o.strip() for o in line.split(',') if o.strip()]
        self.log('re-REGISTER challenged (re-authentication, %s)'
                 % ('new SAs offered' if offers else 'no Security-Server'))
        self.chal = r.get('WWW-Authenticate')
        nonce = base64.b64decode(params(self.chal)['nonce'])
        kind, vals = self.isim.authenticate(nonce[:16], nonce[16:32])
        if kind != 'ok':
            self.down('ISIM synchronisation failure on re-authentication')
            return
        self.res, ck, ik = vals
        self.nc = 1
        if offers:
            self.verify = ', '.join(offers)
            best = sorted(offers, key=lambda o: -float(params(o).get('q', '0')))[0]
            self._ipsec(best, ck, ik)
        authz = self._digest('REGISTER', 'sip:' + self.domain)
        m = self._register_msg(self.expires, authz, self.verify, bool(offers))
        self.send_request(m, self._on_reg)

    def _send_register(self, expires, cb):
        authz = self._digest('REGISTER', 'sip:' + self.domain)
        m = self._register_msg(expires, authz, self.verify, False)
        self.send_request(m, cb)

    def preferred_identity(self):
        for a in getattr(self, 'assoc', []):
            if a.startswith('<sip:+') or a.startswith('<tel:+'):
                return a.split(';')[0] if a.endswith('>') else a
        return '<%s>' % self.isim.impu

    def route_set(self):
        rs = ['<sip:%s:%d;lr>' % (self.p, self.psp)]
        for v in getattr(self, 'service_route', []):
            rs += [x.strip() for x in v.split(',')]
        return rs
