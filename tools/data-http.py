#!/usr/bin/python3
"""HTTP GETs through one interface (SO_BINDTODEVICE, needs root), body
discarded: exercises downlink aggregation with real TCP traffic.
usage: data-http.py IFACE"""
import socket
import ssl
import sys
import time

IFACE = sys.argv[1]
SO_BINDTODEVICE = 25
HOSTS = ['example.com', 'www.google.com', 'www.wikipedia.org', 'ya.ru']


def get(host):
    ip = socket.getaddrinfo(host, 443, socket.AF_INET, socket.SOCK_STREAM)[0][4][0]
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, SO_BINDTODEVICE, IFACE.encode())
    s.settimeout(15)
    t0 = time.time()
    s.connect((ip, 443))
    c = ssl.create_default_context().wrap_socket(s, server_hostname=host)
    c.sendall(('GET / HTTP/1.1\r\nHost: %s\r\nUser-Agent: winglm-test\r\nConnection: close\r\n\r\n' % host).encode())
    n = 0
    while True:
        b = c.recv(65536)
        if not b:
            break
        n += len(b)
    c.close()
    return n, time.time() - t0


for h in HOSTS:
    try:
        n, dt = get(h)
        print('%-20s %7d bytes in %.2f s' % (h, n, dt), flush=True)
    except Exception as e:
        print('%-20s failed: %s' % (h, e), flush=True)
