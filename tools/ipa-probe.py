#!/usr/bin/python3
# read-only probe of the downstream rmnet_ipa driver (extended ioctls)
import fcntl, socket, struct, sys

RMNET_IOCTL_EXTENDED = 0x89FD
GET_SUPPORTED_FEATURES = 0x0000
GET_EPID = 0x0003
GET_EP_PAIR = 0x0010
GET_DRIVER_NAME = 0x0011 if False else 0x000B


def ext(sock, dev, sub, payload=b''):
    buf = bytearray(struct.pack('<I', sub) + payload.ljust(32, b'\0'))
    import ctypes
    cbuf = ctypes.create_string_buffer(bytes(buf), len(buf))
    ifr = struct.pack('16sQ', dev.encode(), ctypes.addressof(cbuf)) + bytes(8)
    fcntl.ioctl(sock.fileno(), RMNET_IOCTL_EXTENDED, ifr)
    return cbuf.raw


s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
dev = sys.argv[1] if len(sys.argv) > 1 else 'rmnet_ipa0'
for name, sub in (('features', GET_SUPPORTED_FEATURES), ('ep_pair', GET_EP_PAIR)):
    try:
        r = ext(s, dev, sub)
        a, b = struct.unpack_from('<II', r, 4)
        print('%-9s ok: %#x %d' % (name, a, b))
    except OSError as e:
        print('%-9s error: %s' % (name, e))
