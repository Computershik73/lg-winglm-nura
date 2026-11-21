#!/bin/sh
# Reset the routes from the earlier manual test, then route through UCM only
amixer -c 0 -q cset "name=PRI_MI2S_RX Audio Mixer MultiMedia1" 0
amixer -c 0 -q cset "name=MultiMedia2 Mixer TX_CDC_DMA_TX_3" 0
amixer -c 0 -q cset "name=MultiMedia1 Mixer TX_CDC_DMA_TX_3" 0
alsaucm -c hw:0 set _verb HiFi set _enadev Speaker set _enadev Mic &
UCM=$!
sleep 1
arecord -D hw:0,1 -f S16_LE -c 1 -r 48000 -d 5 /tmp/mic2.wav > /tmp/arecord.log 2>&1 &
sleep 0.8
aplay -D hw:0,0 /tmp/tone.wav > /tmp/aplay.log 2>&1; echo "aplay exit $?"
wait $!
python3 - <<'EOF'
import math, struct, wave
w = wave.open("/tmp/mic2.wav"); n = w.getnframes(); data = w.readframes(n); w.close()
s = struct.unpack("<%dh" % (len(data) // 2), data)
def goertzel(x, f, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / len(x)
seg = lambda a, b: s[int(a * 48000):int(b * 48000)]
rms = lambda x: math.sqrt(sum(v * v for v in x) / max(len(x), 1))
for name, (a, b) in (("before", (0.0, 0.7)), ("during", (1.2, 3.2)), ("after", (4.2, 4.9))):
    x = seg(a, b)
    print("%-6s rms %7.1f  1kHz %8.2f" % (name, rms(x), goertzel(x, 1000)))
EOF
echo "speaker route now: $(amixer -c 0 cget 'name=PRI_MI2S_RX Audio Mixer MultiMedia1' | grep ': values')"
alsaucm -c hw:0 set _verb HiFi set _disdev Speaker set _disdev Mic
echo "after disable:    $(amixer -c 0 cget 'name=PRI_MI2S_RX Audio Mixer MultiMedia1' | grep ': values')"
