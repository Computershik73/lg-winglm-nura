#!/bin/sh
# Tone through UCM device $1 (Earpiece / Speaker), recorded by the main mic; no PulseAudio session running
DEV=$1
pgrep -x pulseaudio >/dev/null && echo "pulseaudio running: $(pgrep -a -x pulseaudio)"
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/tone-m.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
fr = bytearray()
for i in range(48000 * 2):
    v = int(6000 * math.sin(2 * math.pi * 1000 * i / 48000)); fr += struct.pack("<hh", v, v)
w.writeframes(bytes(fr)); w.close()
PY
alsaucm -c hw:0 set _verb HiFi set _enadev $DEV set _enadev Mic &
U=$!; sleep 1
arecord -D hw:0,1 -f S16_LE -c 1 -r 48000 -d 4 /tmp/ear-rec.wav > /tmp/arecord.log 2>&1 &
sleep 0.8
aplay -D hw:0,0 /tmp/tone-m.wav > /tmp/aplay.log 2>&1; echo "aplay exit $? $(tail -1 /tmp/aplay.log)"
wait $!
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/ear-rec.wav"); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
print("before %.1f  during %.1f" % (g(s[2400:33600]), g(s[52800:120000])))
PY
alsaucm -c hw:0 set _verb HiFi set _disdev $DEV set _disdev Mic
