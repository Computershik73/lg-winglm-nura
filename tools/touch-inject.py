#!/usr/bin/env python3
"""Inject touch taps/swipes into a real touchscreen evdev node (root).

Writing input_events to /dev/input/eventN injects them through the input
core, so libinput/phoc see a genuine touchscreen event.

usage:
  touch-inject.py info  DEV
  touch-inject.py tap   DEV X Y            (raw device coordinates)
  touch-inject.py swipe DEV X1 Y1 X2 Y2 [ms] [steps]
"""
import fcntl
import os
import struct
import sys
import time

EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT = 0
BTN_TOUCH, BTN_TOOL_FINGER = 0x14A, 0x145
ABS_MT_SLOT, ABS_MT_TOUCH_MAJOR = 0x2F, 0x30
ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0x35, 0x36, 0x39
ABS_MT_PRESSURE = 0x3A


def absinfo(fd, code):
    buf = bytearray(24)
    req = (2 << 30) | (24 << 16) | (ord("E") << 8) | (0x40 + code)  # EVIOCGABS
    fcntl.ioctl(fd, req, buf)
    return struct.unpack("6i", bytes(buf))  # value min max fuzz flat res


def ev(fd, t, c, v):
    now = time.time()
    os.write(fd, struct.pack("qqHHi", int(now), int((now % 1) * 1e6), t, c, v))


def frame(fd, x, y, first=False, tid=4242):
    ev(fd, EV_ABS, ABS_MT_SLOT, 0)
    if first:
        ev(fd, EV_ABS, ABS_MT_TRACKING_ID, tid)
    ev(fd, EV_ABS, ABS_MT_POSITION_X, int(x))
    ev(fd, EV_ABS, ABS_MT_POSITION_Y, int(y))
    if first:
        ev(fd, EV_ABS, ABS_MT_TOUCH_MAJOR, 6)
        ev(fd, EV_ABS, ABS_MT_PRESSURE, 60)
        ev(fd, EV_KEY, BTN_TOUCH, 1)
        ev(fd, EV_KEY, BTN_TOOL_FINGER, 1)
    ev(fd, EV_SYN, SYN_REPORT, 0)


def release(fd):
    ev(fd, EV_ABS, ABS_MT_SLOT, 0)
    ev(fd, EV_ABS, ABS_MT_TRACKING_ID, -1)
    ev(fd, EV_KEY, BTN_TOUCH, 0)
    ev(fd, EV_KEY, BTN_TOOL_FINGER, 0)
    ev(fd, EV_SYN, SYN_REPORT, 0)


def main():
    cmd, dev = sys.argv[1], sys.argv[2]
    fd = os.open(dev, os.O_RDWR)
    if cmd == "info":
        for name, code in (("X", ABS_MT_POSITION_X), ("Y", ABS_MT_POSITION_Y)):
            print(name, "min %d max %d" % absinfo(fd, code)[1:3])
    elif cmd == "tap":
        x, y = float(sys.argv[3]), float(sys.argv[4])
        frame(fd, x, y, first=True)
        time.sleep(0.06)
        release(fd)
    elif cmd == "swipe":
        x1, y1, x2, y2 = (float(a) for a in sys.argv[3:7])
        ms = int(sys.argv[7]) if len(sys.argv) > 7 else 300
        steps = int(sys.argv[8]) if len(sys.argv) > 8 else 20
        frame(fd, x1, y1, first=True)
        for i in range(1, steps + 1):
            time.sleep(ms / 1000.0 / steps)
            frame(fd, x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
        time.sleep(0.02)
        release(fd)
    os.close(fd)


if __name__ == "__main__":
    main()
