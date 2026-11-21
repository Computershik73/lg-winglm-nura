#!/bin/sh
# Write BOLERO_CDC_RX_RX0_RX_VOL_CTL (0x1414) = 0 dB while the earpiece path plays, measure before/after
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
R="/sys/kernel/debug/regmap/soc:qcom,msm-audio-apr:qcom,q6core-audio:bolero-cdc"
$E pactl set-card-profile 0 "HiFi (Earpiece, Mic)"; sleep 1.5
$E pactl set-sink-volume @DEFAULT_SINK@ 100%
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC3; amixer -c 0 -q cset "name=ADC4_MIXER Switch" 1; amixer -c 0 -q cset "name=ADC4 MUX" INP5
$E parecord --rate=48000 --channels=1 --format=s16le --file-format=wav /tmp/rv.wav > /dev/null 2>&1 & R2=$!
sleep 0.5
$E paplay /tmp/tone-long.wav & P=$!
sleep 2.4
echo 1414 | sudo tee "$R/address" >/dev/null; echo 00 | sudo tee "$R/data" >/dev/null; echo "write: $?"
sudo grep -E "^1414:" "$R/registers"
wait $P; sleep 0.3; kill $R2; sleep 0.3
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC0; amixer -c 0 -q cset "name=ADC1_MIXER Switch" 1
$E pactl set-sink-volume @DEFAULT_SINK@ 70%
$E pactl set-card-profile 0 "HiFi (Mic, Speaker)"
sleep 1; sudo grep -E "^1414:" "$R/registers"
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/rv.wav"); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
print("before %.1f  after %.1f" % (g(s[int(1.2*48000):int(2.6*48000)]), g(s[int(3.2*48000):int(4.2*48000)])))
PY
