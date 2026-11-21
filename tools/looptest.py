import socket
def test(src, dst):
    r = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    r.bind((dst, 0))
    r.settimeout(1)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind((src, 0))
    try:
        s.sendto(b'x' * 50, r.getsockname())
        d, a = r.recvfrom(100)
        print('%s -> %s: ok (from %s)' % (src, dst, a[0]))
    except Exception as e:
        print('%s -> %s: FAILED %s' % (src, dst, e))
test('127.0.0.1', '198.18.0.1')
test('198.18.0.1', '127.0.0.1')
test('127.0.0.1', '127.0.0.1')
