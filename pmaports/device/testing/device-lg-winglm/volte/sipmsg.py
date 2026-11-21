"""Small SIP message model: parse, build, header access."""
import random
import re

CRLF = '\r\n'
COMPACT = {'v': 'via', 'f': 'from', 't': 'to', 'i': 'call-id', 'm': 'contact', 'l': 'content-length',
           'c': 'content-type', 'k': 'supported', 's': 'subject', 'e': 'content-encoding', 'o': 'event',
           'r': 'refer-to', 'x': 'session-expires'}

REASONS = {100: 'Trying', 180: 'Ringing', 181: 'Call Is Being Forwarded', 183: 'Session Progress',
           200: 'OK', 202: 'Accepted', 400: 'Bad Request', 403: 'Forbidden', 404: 'Not Found',
           408: 'Request Timeout', 415: 'Unsupported Media Type', 420: 'Bad Extension',
           480: 'Temporarily Unavailable', 481: 'Call/Transaction Does Not Exist', 486: 'Busy Here',
           487: 'Request Terminated', 488: 'Not Acceptable Here', 491: 'Request Pending',
           500: 'Server Internal Error', 503: 'Service Unavailable', 603: 'Decline'}


def rnd(n=10):
    return ''.join(random.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(n))


def branch():
    return 'z9hG4bK' + rnd(14)


class Msg:
    def __init__(self, first='', headers=None, body=''):
        self.first = first
        self.headers = headers or []     # list of [name, value], original case
        self.body = body

    # ---- parsing
    @classmethod
    def parse(cls, data):
        if isinstance(data, bytes):
            data = data.decode('utf-8', errors='replace')
        head, sep, body = data.partition('\r\n\r\n')
        lines = head.split('\r\n')
        m = cls(lines[0])
        for l in lines[1:]:
            if l[:1] in (' ', '\t') and m.headers:
                m.headers[-1][1] += ' ' + l.strip()
            elif ':' in l:
                k, v = l.split(':', 1)
                k = k.strip()
                if k.lower() in COMPACT:
                    k = COMPACT[k.lower()].title()
                m.headers.append([k, v.strip()])
        m.body = body
        return m

    @property
    def is_request(self):
        return not self.first.startswith('SIP/2.0')

    @property
    def method(self):
        if self.is_request:
            return self.first.split()[0]
        return self.cseq_method

    @property
    def uri(self):
        return self.first.split()[1]

    @property
    def code(self):
        return int(self.first.split()[1])

    @property
    def cseq(self):
        return int(self.get('CSeq').split()[0])

    @property
    def cseq_method(self):
        return self.get('CSeq').split()[1]

    @property
    def call_id(self):
        return self.get('Call-ID')

    @property
    def top_branch(self):
        v = self.get('Via') or ''
        m = re.search(r'branch=([^;,\s]+)', v)
        return m.group(1) if m else ''

    def get(self, name, default=None):
        n = name.lower()
        for k, v in self.headers:
            if k.lower() == n:
                return v
        return default

    def getall(self, name):
        n = name.lower()
        out = []
        for k, v in self.headers:
            if k.lower() == n:
                out.append(v)
        return out

    def tokens(self, name):
        """comma separated option tags of all headers of that name"""
        out = set()
        for v in self.getall(name):
            out |= set(x.strip().lower() for x in v.split(',') if x.strip())
        return out

    def set(self, name, value):
        n = name.lower()
        for h in self.headers:
            if h[0].lower() == n:
                h[1] = value
                return
        self.headers.append([name, value])

    def remove(self, name):
        n = name.lower()
        self.headers = [h for h in self.headers if h[0].lower() != n]

    def add(self, name, value, top=False):
        if top:
            self.headers.insert(0, [name, value])
        else:
            self.headers.append([name, value])

    def tag(self, name):
        m = re.search(r';\s*tag=([^;>\s]+)', self.get(name) or '')
        return m.group(1) if m else None

    # ---- output
    def encode(self):
        body = self.body or ''
        hs = [h for h in self.headers if h[0].lower() != 'content-length']
        lines = [self.first] + ['%s: %s' % (k, v) for k, v in hs]
        lines.append('Content-Length: %d' % len(body.encode()))
        return (CRLF.join(lines) + CRLF + CRLF + body).encode()


def response(req, code, reason=None, to_tag=None, extra=None, body='', ctype=None):
    r = Msg('SIP/2.0 %d %s' % (code, reason or REASONS.get(code, '')))
    for name in ('Via', 'Record-Route'):
        for v in req.getall(name):
            r.add(name, v)
    r.add('From', req.get('From'))
    to = req.get('To')
    if to_tag and ';tag=' not in to.replace(' ', ''):
        to += ';tag=' + to_tag
    r.add('To', to)
    r.add('Call-ID', req.get('Call-ID'))
    r.add('CSeq', req.get('CSeq'))
    for k, v in (extra or []):
        r.add(k, v)
    if body:
        r.add('Content-Type', ctype or 'application/sdp')
        r.body = body
    return r


def uri_of(nameaddr):
    m = re.search(r'<([^>]+)>', nameaddr or '')
    if m:
        return m.group(1)
    return (nameaddr or '').split(';')[0].strip()


def user_of(uri):
    m = re.match(r'(?:sips?|tel):([^@;>]+)', uri)
    return m.group(1) if m else uri


def hostport_of(uri):
    """(host, port) from sip:user@host:port;params"""
    u = uri.split(':', 1)[1] if ':' in uri else uri
    u = u.split(';')[0].split('?')[0]
    if '@' in u:
        u = u.split('@', 1)[1]
    if u.startswith('['):
        h, _, p = u[1:].partition(']')
        return h, int(p[1:]) if p.startswith(':') else 5060
    h, _, p = u.partition(':')
    return h, int(p) if p else 5060


def params(s):
    out = {}
    for m in re.finditer(r'([\w-]+)\s*=\s*("([^"]*)"|[^,;\s]+)', s or ''):
        out[m.group(1).lower()] = m.group(3) if m.group(3) is not None else m.group(2)
    return out
