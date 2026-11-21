#!/bin/sh
# Tone through UCM device $1, recorded by amic5 (ADC4/INP5, the mic LG uses for speakerphone)
DEV=$1
alsaucm -c hw:0 set _verb HiFi set _enadev $DEV set _enadev Mic &
sleep 1
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 0
amixer -c 0 -q cset "name=TX SMIC MUX0" ADC3
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 1
amixer -c 0 -q cset "name=ADC4 MUX" INP5
amixer -c 0 -q cset "name=ADC3 Volume" 12 2>/dev/null
arecord -D hw:0,1 -f S16_LE -c 1 -r 48000 -d 4 /tmp/ear-rec.wav > /tmp/arecord.log 2>&1 &
sleep 0.8
aplay -D hw:0,0 /tmp/tone-m.wav > /tmp/aplay.log 2>&1
wait $!
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/ear-rec.wav"); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
print("amic5: before %.1f  during %.1f" % (g(s[2400:33600]), g(s[52800:120000])))
PY
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC0; amixer -c 0 -q cset "name=ADC1_MIXER Switch" 1
alsaucm -c hw:0 set _verb HiFi set _disdev $DEV set _disdev Mic
