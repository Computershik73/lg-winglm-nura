#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/tone-long.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
fr = bytearray()
for i in range(48000 * 4):
    v = int(6000 * math.sin(2 * math.pi * 1000 * i / 48000)); fr += struct.pack("<hh", v, v)
w.writeframes(bytes(fr)); w.close()
PY
$E pactl set-card-profile 0 "HiFi (Earpiece, Mic)"; sleep 1.5
$E pactl set-sink-volume @DEFAULT_SINK@ 100%
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC3; amixer -c 0 -q cset "name=ADC4_MIXER Switch" 1; amixer -c 0 -q cset "name=ADC4 MUX" INP5
$E parecord --rate=48000 --channels=1 --format=s16le --file-format=wav /tmp/rv.wav > /dev/null 2>&1 & R=$!
sleep 0.5
$E paplay /tmp/tone-long.wav & P=$!
sleep 2.4
amixer -c 0 cset "name=RX_RX0 Digital Volume" 60 >/dev/null 2>&1; echo "set 60: exit $?"
wait $P; sleep 0.3; kill $R; sleep 0.3
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC0; amixer -c 0 -q cset "name=ADC1_MIXER Switch" 1
amixer -c 0 -q cset "name=RX_RX0 Digital Volume" 84 2>/dev/null
$E pactl set-sink-volume @DEFAULT_SINK@ 70%
$E pactl set-card-profile 0 "HiFi (Mic, Speaker)"
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/rv.wav"); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
a = g(s[int(1.2*48000):int(2.6*48000)]); b = g(s[int(3.2*48000):int(4.2*48000)])
print("before set %.1f  after set %.1f  ratio %.1f dB" % (a, b, 20*math.log10(max(b,1e-3)/max(a,1e-3))))
PY
