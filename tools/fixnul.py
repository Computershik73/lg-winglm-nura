import glob, sys
for p in glob.glob(sys.argv[1] + '/*.py'):
    d = open(p, 'rb').read()
    n = d.replace(b'\r\n', b'\n')
    n = n.replace(b"b'" + bytes([0]) + b"'", b"b'\\0'")
    n = n.replace(b"b'" + bytes([1]) + b"'", b"b'\\x01'")
    if bytes([0]) in n:
        i = n.find(bytes([0]))
        print('still NUL in', p, n[i - 40:i + 10])
    if n != d:
        open(p, 'wb').write(n)
        print('fixed', p)
