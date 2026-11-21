import fcntl, os, select, struct, termios, time, sys
TIOCMGET, TIOCPMGET = 0x5415, 0x544D
RF = "/sys/class/rfkill/rfkill0/soft"
def bits():
    v = struct.unpack("I", fcntl.ioctl(fd, TIOCMGET, b"\0\0\0\0"))[0]
    return "CTS=%d RTS=%d DSR=%d CD=%d" % (bool(v & 0x20), bool(v & 0x4), bool(v & 0x100), bool(v & 0x40))
def setup(baud, flow):
    a = termios.tcgetattr(fd)
    a[0] = a[1] = a[3] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL | (termios.CRTSCTS if flow else 0)
    a[4] = a[5] = getattr(termios, "B%d" % baud)
    a[6][termios.VMIN] = 0; a[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, a)
def rd(t):
    end = time.time() + t; out = b""
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r: out += os.read(fd, 4096)
    return out
open(RF, "w").write("1"); time.sleep(0.3)
fd = os.open("/dev/ttyHS0", os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
print("TIOCPMGET ->", fcntl.ioctl(fd, TIOCPMGET))
setup(115200, False)
print("before power:", bits())
open(RF, "w").write("0")
t0 = time.time(); got = rd(0.5)
print("after power: %s, spontaneous rx: %s" % (bits(), got.hex()))
cmd = bytes([0x01, 0x00, 0xFC, 0x01, 0x19])
for flow in (False, True):
    setup(115200, flow)
    n = os.write(fd, cmd)
    print("flow=%s wrote %d, %s, rx: %s" % (flow, n, bits(), rd(1.0).hex()))
# boot pulses then version again
setup(2400, False); os.write(fd, b"\xC0"); termios.tcdrain(fd); time.sleep(0.05)
setup(115200, False); os.write(fd, b"\xFC"); termios.tcdrain(fd); time.sleep(0.15)
print("after pulses rx:", rd(0.3).hex(), bits())
os.write(fd, cmd); print("version after pulses rx:", rd(1.0).hex())
os.close(fd)
open(RF, "w").write("1")
