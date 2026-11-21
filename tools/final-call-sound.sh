#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/tone-m.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
fr = bytearray()
for i in range(48000 * 2):
    v = int(6000 * math.sin(2 * math.pi * 1000 * i / 48000)); fr += struct.pack("<hh", v, v)
w.writeframes(bytes(fr)); w.close()
PY
sig() { sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/9 org.freedesktop.ModemManager1.Call.StateChanged int32:$1 int32:$2 uint32:0; }
meas() {
	echo "  sink $($E pactl get-sink-volume @DEFAULT_SINK@ | grep -o "[0-9]*%" | head -1) mute $($E pactl get-sink-mute @DEFAULT_SINK@ | cut -d" " -f2), source $($E pactl get-source-volume @DEFAULT_SOURCE@ | grep -o "[0-9]*%" | head -1) mute $($E pactl get-source-mute @DEFAULT_SOURCE@ | cut -d" " -f2)"
	$E pactl set-sink-volume @DEFAULT_SINK@ 100%; $E pactl set-source-volume @DEFAULT_SOURCE@ 100%
	amixer -c 0 -q cset "name=ADC1_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC3; amixer -c 0 -q cset "name=ADC4_MIXER Switch" 1; amixer -c 0 -q cset "name=ADC4 MUX" INP5
	$E parecord --rate=48000 --channels=1 --format=s16le --file-format=wav /tmp/fc.wav > /dev/null 2>&1 & R=$!
	sleep 0.6; $E paplay /tmp/tone-m.wav; sleep 0.3; kill $R; sleep 0.3
	amixer -c 0 -q cset "name=ADC4_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC0; amixer -c 0 -q cset "name=ADC1_MIXER Switch" 1
	python3 - "$1" <<'PY'
import math, struct, wave, sys
w = wave.open("/tmp/fc.wav"); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
print("  %-9s tone at the top mic: before %.1f  during %.1f" % (sys.argv[1], g(s[0:24000]), g(s[40000:110000])))
PY
}
$E pactl set-sink-volume @DEFAULT_SINK@ 100%
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2
echo "call mode: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
sig 0 1; sleep 2; echo "dialing: voice PCM $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
sig 1 4; sleep 1
meas Earpiece
$E callaudiocli -s 1 >/dev/null 2>&1; sleep 2; echo "speaker: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//'), voice PCM $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
meas Speaker
$E callaudiocli -s 0 >/dev/null 2>&1; sleep 2
sig 4 7; sleep 1; echo "ended: voice PCM $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
$E callaudiocli -m 0 >/dev/null 2>&1; sleep 2; echo "after: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
$E pactl set-sink-volume @DEFAULT_SINK@ 70%
