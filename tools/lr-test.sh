#!/bin/sh
# Play a 1 kHz tone on the left only, right only and mono through PulseAudio; measure it with the main mic
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
amixer -c 0 cget numid=3295 | grep -E "values|Items" | tr '\n' ' '; echo
python3 - <<'PY'
import math, struct, wave
for name, l, r, ch in (("left", 1, 0, 2), ("right", 0, 1, 2), ("mono", 1, 1, 1)):
    w = wave.open("/tmp/tone-%s.wav" % name, "wb"); w.setnchannels(ch); w.setsampwidth(2); w.setframerate(48000)
    fr = bytearray()
    for i in range(48000 * 2):
        v = int(9000 * math.sin(2 * math.pi * 1000 * i / 48000))
        fr += struct.pack("<h", v * l) + (struct.pack("<h", v * r) if ch == 2 else b"")
    w.writeframes(bytes(fr)); w.close()
PY
for t in left right mono; do
	$E parecord --rate=48000 --channels=1 --format=s16le --file-format=wav /tmp/rec-$t.wav > /dev/null 2>&1 &
	R=$!; sleep 0.8
	$E paplay /tmp/tone-$t.wav; sleep 0.5; kill $R; sleep 0.3
done
python3 - <<'PY'
import math, struct, wave
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
for t in ("left", "right", "mono"):
    w = wave.open("/tmp/rec-%s.wav" % t); d = w.readframes(w.getnframes()); w.close()
    s = struct.unpack("<%dh" % (len(d) // 2), d)
    print("%-5s 1kHz before %6.1f during %6.1f" % (t, g(s[4800:33600]), g(s[52800:120000])))
PY
