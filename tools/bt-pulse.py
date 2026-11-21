import fcntl, os, select, struct, termios, time
TIOCPMGET = 0x544D
def opn():
    fd = os.open("/dev/ttyHS0", os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    fcntl.ioctl(fd, TIOCPMGET)
    return fd
def setup(fd, baud, flow):
    a = termios.tcgetattr(fd)
    a[0] = a[1] = a[3] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL | (termios.CRTSCTS if flow else 0)
    a[4] = a[5] = getattr(termios, "B%d" % baud)
    a[6][termios.VMIN] = 0; a[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, a)
def rd(fd, t):
    end = time.time() + t; out = b""
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r: out += os.read(fd, 4096)
    return out
def version(fd, baud):
    setup(fd, baud, True); termios.tcflush(fd, termios.TCIFLUSH)
    os.write(fd, bytes([0x01, 0x00, 0xFC, 0x01, 0x19]))
    r = rd(fd, 0.6)
    i = r.find(b"\x04\x0e")
    if i >= 0 and len(r) >= i + 21:
        p = r[i + 3:]
        return "patch 0x%04x" % struct.unpack_from("<H", p, 11)[0]
    return "raw " + r.hex()
fd = opn()
for b in (115200, 3000000):
    print("before pulses @%d: %s" % (b, version(fd, b)))
# pulses as hci_qca: flow off, 0xC0 @2400, 0xFC @115200
setup(fd, 2400, False); os.write(fd, b"\xC0"); termios.tcdrain(fd); time.sleep(0.02)
setup(fd, 115200, False); os.write(fd, b"\xFC"); termios.tcdrain(fd); time.sleep(0.1)
os.close(fd); time.sleep(0.05)
fd = opn()
for b in (115200, 3000000, 115200):
    print("after pulses @%d: %s" % (b, version(fd, b)))
os.close(fd)
