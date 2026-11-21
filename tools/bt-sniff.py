import fcntl, os, select, termios, time
fd = os.open("/dev/ttyHS0", os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
fcntl.ioctl(fd, 0x544D)
def setup(baud):
    a = termios.tcgetattr(fd)
    a[0] = a[1] = a[3] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL | termios.CRTSCTS
    a[4] = a[5] = getattr(termios, "B%d" % baud)
    a[6][termios.VMIN] = 0; a[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, a)
for b in (3000000, 3200000, 115200, 3000000):
    setup(b); termios.tcflush(fd, termios.TCIFLUSH)
    end = time.time() + 0.5; out = b""
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r: out += os.read(fd, 4096)
    print("@%d: %d bytes: %s" % (b, len(out), out[:48].hex()))
# HCI reset at 3M and see the answer
setup(3000000); termios.tcflush(fd, termios.TCIFLUSH)
os.write(fd, bytes([0x01, 0x03, 0x0c, 0x00])); time.sleep(0.3)
try: print("reset answer:", os.read(fd, 256).hex())
except BlockingIOError: print("reset answer: none")
os.write(fd, b"\xFD"); time.sleep(0.1)
try: print("after 0xFD wake:", os.read(fd, 256).hex())
except BlockingIOError: print("after 0xFD: none")
