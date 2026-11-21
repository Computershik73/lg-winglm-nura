#!/usr/bin/python3
"""write a quiet sine tone WAV: tone.py OUT SECONDS [DBFS]"""
import math, struct, sys, wave
out, secs = sys.argv[1], float(sys.argv[2])
dbfs = float(sys.argv[3]) if len(sys.argv) > 3 else -30
amp = 32767 * 10 ** (dbfs / 20)
rate = 48000
with wave.open(out, 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
    frames = bytearray()
    for i in range(int(rate * secs)):
        v = int(amp * math.sin(2 * math.pi * 440 * i / rate))
        frames += struct.pack('<hh', v, v)
    w.writeframes(bytes(frames))
