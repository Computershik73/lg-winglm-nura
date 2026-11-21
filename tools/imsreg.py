#!/usr/bin/python3
"""IMS registration test (VoLTE prerequisite) for the LG Wing on MegaFon.

IMS PDN over IPA -> SIP REGISTER (unprotected) -> 401 with AKA challenge ->
ISIM AUTHENTICATE -> IPsec SAs (TS 33.203) -> protected REGISTER -> 200 OK
-> hold N seconds -> de-register -> tear down.
usage: imsreg.py [HOLD_SECONDS]
"""
import base64
import hashlib
import os
import random
import re
import select
import socket
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ipadata import Ipa, Pdn, modem_ids, lte_cell, run
from uimtool import Uim, nai

HOLD = float(sys.argv[1]) if len(sys.argv) > 1 else 20
SECRETS = []


def mask(s):
    for x in SECRETS:
        if x:
            s = s.replace(x, '<%s>' % ('*' * 3))
    s = re.sub(r'\+?7\d{10}', '<msisdn>', s)
    s = re.sub(r'utran-cell-id-3gpp=[0-9A-Fa-f]+', 'utran-cell-id-3gpp=<cell>', s)
    return s


def log(*a):
    print(time.strftime('%H:%M:%S'), mask(' '.join(str(x) for x in a)), flush=True)


# ---------------------------------------------------------------- ISIM
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
    raise RuntimeError('no ISIM')


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
            i = 1
            out = []
            for _ in range(3):
                ln = r[i]
                out.append(r[i + 1:i + 1 + ln])
                i += 1 + ln
            return 'ok', out          # RES, CK, IK
        if r[0] == 0xDC:
            return 'sync', [r[2:2 + r[1]]]   # AUTS
        raise RuntimeError('AUTHENTICATE: unexpected %s' % r[:2].hex())

    def close(self):
        self.u.close(self.ch)


# ---------------------------------------------------------------- SIP
def rnd(n=10):
    return ''.join(random.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(n))


def parse(msg):
    head, _, body = msg.partition('\r\n\r\n')
    lines = head.split('\r\n')
    hdrs = []
    for l in lines[1:]:
        if l[:1] in (' ', '\t') and hdrs:
            hdrs[-1] = (hdrs[-1][0], hdrs[-1][1] + ' ' + l.strip())
        elif ':' in l:
            k, v = l.split(':', 1)
            hdrs.append((k.strip().lower(), v.strip()))
    return lines[0], hdrs, body


def hget(hdrs, name):
    return [v for k, v in hdrs if k == name.lower()]


def params(s):
    out = {}
    for m in re.finditer(r'([\w-]+)\s*=\s*("([^"]*)"|[^,;\s]+)', s):
        out[m.group(1).lower()] = m.group(3) if m.group(3) is not None else m.group(2)
    return out


class Ims:
    def __init__(self, ue_ip, pcscf, isim, imei, pani):
        self.ue, self.p, self.isim, self.imei, self.pani = ue_ip, pcscf, isim, imei, pani
        self.callid = rnd(16) + '@' + ue_ip
        self.ftag = rnd(8)
        self.cseq = 0
        self.pc = random.randint(15000, 32000) * 2 + 1
        self.ps = self.pc + 1
        self.spi_c = random.randint(0x10000, 0x7FFFFFFF)
        self.spi_s = self.spi_c + 1
        self.unprot = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.unprot.bind((ue_ip, 5060))
        self.sc = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sc.bind((ue_ip, self.pc))
        self.ss = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.ss.bind((ue_ip, self.ps))
        self.sec_server = None
        self.auth = None

    def sec_client(self):
        offers = []
        for alg in ('hmac-sha-1-96', 'hmac-md5-96'):
            for ealg in ('aes-cbc', 'null'):
                offers.append('ipsec-3gpp;alg=%s;ealg=%s;prot=esp;mod=trans;spi-c=%d;spi-s=%d;port-c=%d;port-s=%d'
                              % (alg, ealg, self.spi_c, self.spi_s, self.pc, self.ps))
        return ', '.join(offers)

    def register(self, via_port, expires=600000, authorization=None, verify=None, minimal=False):
        self.cseq += 1
        uri = 'sip:' + self.isim.domain
        contact = ('<sip:%s@%s:%d>;+sip.instance="<urn:gsma:imei:%s-%s-0>";'
                   '+g.3gpp.icsi-ref="urn%%3Aurn-7%%3A3gpp-service.ims.icsi.mmtel";audio;expires=%d'
                   % (self.isim.impi.split('@')[0], self.ue, self.ps, self.imei[:8], self.imei[8:14], expires))
        h = [
            'REGISTER %s SIP/2.0' % uri,
            'Via: SIP/2.0/UDP %s:%d;branch=z9hG4bK%s;rport' % (self.ue, via_port, rnd(12)),
            'Max-Forwards: 70',
            'From: <%s>;tag=%s' % (self.isim.impu, self.ftag),
            'To: <%s>' % self.isim.impu,
            'Call-ID: %s' % self.callid,
            'CSeq: %d REGISTER' % self.cseq,
            'Contact: %s' % contact,
            'Expires: %d' % expires,
            'Supported: path,sec-agree',
            'Require: sec-agree',
            'Proxy-Require: sec-agree',
            'Allow: INVITE,ACK,CANCEL,BYE,UPDATE,PRACK,INFO,MESSAGE,OPTIONS,NOTIFY,REFER',
            'P-Access-Network-Info: %s' % self.pani,
            'User-Agent: winglm-ims/0.1',
            'Security-Client: %s' % self.sec_client(),
        ]
        if minimal:
            h = [x for x in h if not x.startswith(('Security-Client', 'Allow', 'User-Agent', 'P-Access-Network-Info'))]
        if verify:
            h.append('Security-Verify: %s' % verify)
        h.append('Authorization: %s' % (authorization or
                 'Digest username="%s",realm="%s",uri="%s",nonce="",response=""'
                 % (self.isim.impi, self.isim.domain, uri)))
        h.append('Content-Length: 0')
        return '\r\n'.join(h) + '\r\n\r\n'

    def xchg(self, sock, dst, msg, timeout=10):
        log('>>>', msg.split('\r\n')[0], '(%d bytes) to %s:%d' % (len(msg), dst[0], dst[1]))
        sock.sendto(msg.encode(), dst)
        end = time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([sock, self.ss, self.sc, self.unprot], [], [], max(0, end - time.time()))
            for s in r:
                data, src = s.recvfrom(65535)
                txt = data.decode(errors='replace')
                first, hdrs, _ = parse(txt)
                log('<<<', first, 'from %s:%d' % src)
                if first.startswith('SIP/2.0'):
                    code = int(first.split()[1])
                    if code >= 200:
                        return code, hdrs, txt
                else:
                    log('    (request from network, ignored)')
        return None, [], ''

    def digest(self, chal, res, method='REGISTER', nc=1):
        p = params(chal)
        uri = 'sip:' + self.isim.domain
        ha1 = hashlib.md5(('%s:%s:' % (self.isim.impi, p['realm'])).encode() + res).hexdigest()
        ha2 = hashlib.md5(('%s:%s' % (method, uri)).encode()).hexdigest()
        a = 'Digest username="%s",realm="%s",uri="%s",nonce="%s",algorithm=AKAv1-MD5' % (
            self.isim.impi, p['realm'], uri, p['nonce'])
        if 'qop' in p:
            cn = rnd(16)
            resp = hashlib.md5(('%s:%s:%08x:%s:auth:%s' % (ha1, p['nonce'], nc, cn, ha2)).encode()).hexdigest()
            a += ',qop=auth,nc=%08x,cnonce="%s"' % (nc, cn)
        else:
            resp = hashlib.md5(('%s:%s:%s' % (ha1, p['nonce'], ha2)).encode()).hexdigest()
        a += ',response="%s"' % resp
        if 'opaque' in p:
            a += ',opaque="%s"' % p['opaque']
        return a

    def ipsec(self, srv, ck, ik):
        s = params(srv)
        alg, ealg = s['alg'], s.get('ealg', 'null')
        spi_cp, spi_sp, pcp, psp = int(s['spi-c']), int(s['spi-s']), int(s['port-c']), int(s['port-s'])
        self.pcp, self.psp = pcp, psp
        if alg == 'hmac-sha-1-96':
            auth = "auth-trunc 'hmac(sha1)' 0x%s 96" % (ik + b'\0' * 4).hex()
        else:
            auth = "auth-trunc 'hmac(md5)' 0x%s 96" % ik.hex()
        if ealg == 'aes-cbc':
            enc = "enc 'cbc(aes)' 0x%s" % ck.hex()
        elif ealg == 'des-ede3-cbc':
            enc = "enc 'cbc(des3_ede)' 0x%s" % (ck + ck[:8]).hex()
        else:
            enc = "enc 'ecb(cipher_null)' ''"
        U, P = self.ue, self.p
        cmds = [
            # outbound: UE client -> P-CSCF server, UE server -> P-CSCF client
            'ip xfrm state add src %s dst %s proto esp spi %d mode transport %s %s' % (U, P, spi_sp, auth, enc),
            'ip xfrm state add src %s dst %s proto esp spi %d mode transport %s %s' % (U, P, spi_cp, auth, enc),
            # inbound: P-CSCF server -> UE client, P-CSCF client -> UE server
            'ip xfrm state add src %s dst %s proto esp spi %d mode transport %s %s' % (P, U, self.spi_c, auth, enc),
            'ip xfrm state add src %s dst %s proto esp spi %d mode transport %s %s' % (P, U, self.spi_s, auth, enc),
        ]
        for proto in ('udp', 'tcp'):
            cmds += [
                'ip xfrm policy add src %s/32 dst %s/32 sport %d dport %d proto %s dir out '
                'tmpl src %s dst %s proto esp spi %d mode transport' % (U, P, self.pc, psp, proto, U, P, spi_sp),
                'ip xfrm policy add src %s/32 dst %s/32 sport %d dport %d proto %s dir out '
                'tmpl src %s dst %s proto esp spi %d mode transport' % (U, P, self.ps, pcp, proto, U, P, spi_cp),
            ]
        for c in cmds:
            r = run(c)
            if r.returncode:
                raise RuntimeError('xfrm: %s' % (r.stdout + r.stderr).strip())
        log('IPsec SAs up: alg %s ealg %s, P-CSCF ports c=%d s=%d' % (alg, ealg, pcp, psp))


def main():
    log('IMS registration test, hold %ds' % HOLD)
    run('ip xfrm policy flush; ip xfrm state flush')
    ipa = Ipa(log)
    pdn = Pdn(2, profile=2, log=log)
    isim = None
    try:
        st = pdn.start()
        log('IMS PDN up: ip %s pcscf %s' % (st.get('ip'), st.get('pcscf')))
        if os.environ.get('PCAP'):
            import subprocess
            subprocess.Popen('tcpdump -i %s -n -s 0 -U -w %s' % (pdn.ifname, os.environ['PCAP']), shell=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(1.5)
        isim = Isim()
        SECRETS.extend([isim.impi.split('@')[0]])
        imei = modem_ids()
        SECRETS.extend([imei, '%s-%s-%s' % (imei[:8], imei[8:14], imei[14:]), '%s-%s-0' % (imei[:8], imei[8:14])])
        plmn, tac, eci = lte_cell()
        pani = '3GPP-E-UTRAN-FDD; utran-cell-id-3gpp=%s%04X%07X' % (plmn, tac, eci)
        pcscf = st['pcscf'][0]
        pdn.route(pcscf)
        ims = Ims(st['ip'], pcscf, isim, imei, pani)

        code, hdrs, txt = ims.xchg(ims.unprot, (pcscf, 5060), ims.register(5060))
        if code != 401:
            log('unexpected answer %s:\n%s' % (code, txt))
            return
        chal = hget(hdrs, 'www-authenticate')[0]
        srv = hget(hdrs, 'security-server')
        log('challenge:', re.sub(r'nonce="[^"]*"', 'nonce="..."', chal))
        log('security-server:', srv)
        nonce = base64.b64decode(params(chal)['nonce'])
        rand, autn = nonce[:16], nonce[16:32]
        kind, vals = isim.authenticate(rand, autn)
        if kind != 'ok':
            log('ISIM: synchronisation failure (AUTS) - would need a resync REGISTER')
            return
        res, ck, ik = vals
        log('ISIM AKA ok: RES %d bytes, CK/IK 16 bytes' % len(res))
        # pick the server's preferred offer (highest q)
        offers = []
        for line in srv:
            offers += [o.strip() for o in line.split(',') if o.strip()]
        best = sorted(offers, key=lambda o: -float(params(o).get('q', '0')))[0]
        ims.ipsec(best, ck, ik)
        authz = ims.digest(chal, res)
        code, hdrs, txt = ims.xchg(ims.sc, (pcscf, ims.psp), ims.register(ims.pc, authorization=authz,
                                                                           verify=', '.join(offers)))
        if code != 200:
            log('REGISTER failed %s:\n%s' % (code, txt))
            return
        log('*** IMS REGISTERED ***')
        for h in ('p-associated-uri', 'service-route', 'path', 'contact', 'expires'):
            for v in hget(hdrs, h):
                log('   %s: %s' % (h, v))
        t0 = time.time()
        while time.time() - t0 < HOLD:
            r, _, _ = select.select([ims.ss, ims.sc], [], [], 1)
            for s in r:
                data, src = s.recvfrom(65535)
                log('<<< (idle)', data.decode(errors='replace').split('\r\n')[0], 'from %s:%d' % src)
        # (a) refresh with the same request as the registration
        code, hdrs, txt = ims.xchg(ims.sc, (pcscf, ims.psp), ims.register(ims.pc, authorization=ims.digest(chal, res, nc=2),
                                   verify=', '.join(offers)), timeout=12)
        log('refresh:', code)
        if code:
            log(txt.split(chr(13) + chr(10) + chr(13) + chr(10))[0])
        # (b) minimal de-registration
        for attempt in range(2):
            code, hdrs, txt = ims.xchg(ims.sc, (pcscf, ims.psp), ims.register(ims.pc, expires=0,
                                       authorization=ims.digest(chal, res, nc=3 + attempt),
                                       verify=', '.join(offers), minimal=True), timeout=12)
            log('de-register:', code)
            if code:
                log(txt.split(chr(13) + chr(10) + chr(13) + chr(10))[0])
                break
    finally:
        if isim:
            isim.close()
        run('ip xfrm policy flush; ip xfrm state flush')
        pdn.stop()
        log('torn down')


main()
