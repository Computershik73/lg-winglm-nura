#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E parecord --rate=48000 --channels=1 --format=s16le --file-format=wav /tmp/pa-mic.wav > /dev/null 2>&1 &
R=$!
sleep 1
$E paplay /tmp/tone.wav; echo "paplay exit $?"
sleep 1; kill $R; sleep 0.5
python3 - <<'EOF'
import math, struct, wave
w = wave.open("/tmp/pa-mic.wav"); n = w.getnframes(); data = w.readframes(n); w.close()
s = struct.unpack("<%dh" % (len(data) // 2), data)
def goertzel(x, f, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
rms = lambda x: math.sqrt(sum(v * v for v in x) / max(len(x), 1))
print("recorded %.1f s" % (len(s) / 48000))
for name, (a, b) in (("before", (0.1, 0.8)), ("during", (1.5, 3.5))):
    x = s[int(a * 48000):int(b * 48000)]
    print("%-6s rms %7.1f  1kHz %8.2f" % (name, rms(x), goertzel(x, 1000)))
EOF
