#!/bin/sh
# Real incoming call test: wait for a ringing call, answer it, check the voice
# path, measure the earpiece (top mic next to it), beep to the caller on the
# speaker, hang up after ~60 s if the caller hasn't.
WAIT=${1:-1500}
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
ts() { date +%H:%M:%S; }
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/tone-m.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
fr = bytearray()
for i in range(48000 * 2):
    v = int(8000 * math.sin(2 * math.pi * 1000 * i / 48000)); fr += struct.pack("<hh", v, v)
w.writeframes(bytes(fr)); w.close()
PY
echo "$(ts) waiting up to ${WAIT}s for an incoming call"
C=""
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt $WAIT ]; do
	L=$(mmcli -m any --voice-list-calls 2>/dev/null | grep -o "/Call/[0-9]* incoming (ringing-in)" | head -1)
	if [ -n "$L" ]; then C=$(echo "$L" | sed 's|/Call/\([0-9]*\).*|\1|'); break; fi
	sleep 1
done
[ -z "$C" ] && { echo "$(ts) no call"; exit 1; }
echo "$(ts) ringing: call $C"
sleep 2
sudo mmcli -c $C --accept 2>&1 | tail -1
sleep 3
echo "$(ts) call state: $(mmcli -c $C -K 2>/dev/null | grep 'call.properties.state ' | sed 's/.*: //')"
echo "  voice PCM play: $(head -1 /proc/asound/card0/pcm2p/sub0/status 2>&1)  capture: $(head -1 /proc/asound/card0/pcm2c/sub0/status 2>&1)"
echo "  card profile: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
echo "  routes: earpiece voice $(amixer -c 0 cget "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" | grep -o ': values=.*' ), mic voice $(amixer -c 0 cget "name=VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" | grep -o ': values=.*'), EAR $(amixer -c 0 cget "name=EAR_RDAC Switch" | grep -o ': values=.*')"
dmesg | tail -n 30 | grep -iE "voice|voc_|q6|afe|adm" | tail -5 | cut -c1-150

# earpiece downlink: the top mic (amic5) sits next to the earpiece
echo "$(ts) recording the earpiece for 14 s (caller: please talk)"
$E pactl set-source-volume @DEFAULT_SOURCE@ 100%
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC3
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 1; amixer -c 0 -q cset "name=ADC4 MUX" INP5
$E parecord --rate=48000 --channels=1 --format=s16le --file-format=wav /tmp/rc-ear.wav > /dev/null 2>&1 & R=$!
sleep 14; kill $R; sleep 0.3
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC0
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 1
python3 - <<'PY'
import math, struct, wave
w = wave.open("/tmp/rc-ear.wav"); d = w.readframes(w.getnframes()); r = w.getframerate(); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
out = []
for k in range(0, len(s) - r // 2, r // 2):
    x = s[k:k + r // 2]; m = sum(x) / len(x)
    out.append("%d" % math.sqrt(sum((v - m) ** 2 for v in x) / len(x)))
print("  top-mic RMS per 0.5 s:", " ".join(out))
PY

# uplink: speakerphone + two beeps the caller should hear
echo "$(ts) speakerphone + beeps for the caller"
$E callaudiocli -s 1 >/dev/null 2>&1; sleep 2
echo "  card profile: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
$E paplay /tmp/tone-m.wav; sleep 1; $E paplay /tmp/tone-m.wav
$E callaudiocli -s 0 >/dev/null 2>&1; sleep 1
echo "  back to: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"

# leave the line open a little, then hang up if the caller hasn't
for i in $(seq 1 30); do
	st=$(mmcli -c $C -K 2>/dev/null | grep 'call.properties.state ' | sed 's/.*: //')
	[ "$st" = "active" ] || break
	sleep 1
done
[ "$st" = "active" ] && sudo mmcli -c $C --hangup 2>&1 | tail -1
sleep 2
echo "$(ts) call state now: $(mmcli -c $C -K 2>/dev/null | grep 'call.properties.state ' | sed 's/.*: //') voice PCM: $(head -1 /proc/asound/card0/pcm2p/sub0/status 2>&1)"
echo "  card profile: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
