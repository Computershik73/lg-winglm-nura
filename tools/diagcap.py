#!/usr/bin/env python3
# Minimal /dev/diag (downstream msm diagchar) memory-device client:
# enables F3 message masks and records raw diag packets.
# usage: diagcap.py OUT.bin SECONDS [MASK] [-- shell command run after masks are set]
import os, sys, struct, fcntl, threading, time, subprocess

DIAG_IOCTL_SWITCH_LOGGING = 7
MEMORY_DEVICE_MODE = 2
USER_SPACE_DATA_TYPE = 0x20


def crc16(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0x8408 if crc & 1 else crc >> 1
    return (~crc) & 0xFFFF


def hdlc_enc(payload):
    p = payload + struct.pack('<H', crc16(payload))
    out = bytearray()
    for b in p:
        if b in (0x7E, 0x7D):
            out += bytes([0x7D, b ^ 0x20])
        else:
            out.append(b)
    out.append(0x7E)
    return bytes(out)


def hdlc_frames(buf):
    """split a buffer of HDLC frames, return decoded payloads"""
    res = []
    for fr in buf.split(b'\x7e'):
        if not fr:
            continue
        out = bytearray()
        esc = False
        for b in fr:
            if esc:
                out.append(b ^ 0x20)
                esc = False
            elif b == 0x7D:
                esc = True
            else:
                out.append(b)
        if len(out) >= 3 and crc16(bytes(out[:-2])) == struct.unpack('<H', out[-2:])[0]:
            res.append(bytes(out[:-2]))
        elif out:
            res.append(b'BADCRC' + bytes(out))
    return res


def entries_to_packets(data):
    # non-HDLC framing: 7e 01 len16 payload 7e
    pkts = []
    if len(data) >= 4 and data[0] == 0x7E and data[1] == 0x01:
        i = 0
        while i + 4 <= len(data) and data[i] == 0x7E and data[i + 1] == 0x01:
            ln = struct.unpack_from('<H', data, i + 2)[0]
            pkts.append(data[i + 4:i + 4 + ln])
            i += 4 + ln + 1
        return pkts
    return hdlc_frames(data)


def main():
    out = sys.argv[1]
    secs = float(sys.argv[2])
    mask = int(sys.argv[3], 0) if len(sys.argv) > 3 and sys.argv[3] != '--' else 0x1F
    cmd = None
    if '--' in sys.argv:
        cmd = ' '.join(sys.argv[sys.argv.index('--') + 1:])

    fd = os.open('/dev/diag', os.O_RDWR)
    param = bytearray(struct.pack('<IIIBBBBii', MEMORY_DEVICE_MODE, 0xFF, 0,
                                  0, 0, 0, 0, 0, 1))
    fcntl.ioctl(fd, DIAG_IOCTL_SWITCH_LOGGING, param)

    f = open(out, 'wb')
    lock = threading.Lock()
    stats = {'pkts': 0}
    stop = [False]

    def reader():
        while not stop[0]:
            try:
                buf = os.read(fd, 1 << 20)
            except OSError as e:
                time.sleep(0.05)
                continue
            if len(buf) < 8:
                continue
            dtype = struct.unpack_from('<i', buf, 0)[0]
            if dtype != USER_SPACE_DATA_TYPE:
                continue
            n = struct.unpack_from('<i', buf, 4)[0]
            off = 8
            for _ in range(n):
                if off + 4 > len(buf):
                    break
                ln = struct.unpack_from('<i', buf, off)[0]
                off += 4
                data = buf[off:off + ln]
                off += ln
                for p in entries_to_packets(data):
                    with lock:
                        f.write(struct.pack('<dI', time.time(), len(p)) + p)
                        stats['pkts'] += 1

    t = threading.Thread(target=reader, daemon=True)
    t.start()

    def send(payload):
        os.write(fd, struct.pack('<i', USER_SPACE_DATA_TYPE) + hdlc_enc(payload))

    send(b'\x00')                                          # version (sanity)
    send(bytes([0x7D, 0x01]))                              # ssid ranges
    send(struct.pack('<BBBBI', 0x7D, 0x05, 0, 0, mask))    # all RT masks
    send(bytes([0x60, 0x01]))                              # event reports on
    time.sleep(2)
    if cmd:
        subprocess.Popen(cmd, shell=True)
    t0 = time.time()
    while time.time() - t0 < secs:
        time.sleep(1)
    send(struct.pack('<BBBBI', 0x7D, 0x05, 0, 0, 0))       # masks off
    send(bytes([0x60, 0x00]))
    time.sleep(0.5)
    stop[0] = True
    with lock:
        f.flush()
    print('packets:', stats['pkts'])
    os._exit(0)


main()
