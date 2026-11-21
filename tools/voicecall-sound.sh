#!/bin/sh
# Voice Call verb with the DSP voice session open: tone on Earpiece then Speaker, recorded by the top mic (amic5)
c() { amixer -c 0 -q cset "name=$1" "$2"; }
v() { amixer -c 0 cget "name=$1" | sed -n "s/.*: values=//p"; }
meas() {
	echo "  [$1] RX0-MM1=$(v "RX_CDC_DMA_RX_0 Audio Mixer MultiMedia1") PRI-MM1=$(v "PRI_MI2S_RX Audio Mixer MultiMedia1") EAR=$(v "RX_EAR Mode") EAR_RDAC=$(v "EAR_RDAC Switch") RX0-voice=$(v "RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1") PRI-voice=$(v "PRI_MI2S_RX_Voice Mixer VoiceMMode1")" >&2
	arecord -D hw:0,1 -f S16_LE -c 1 -r 48000 -d 4 /tmp/vc-rec.wav > /dev/null 2>&1 &
	R=$!; sleep 0.8; aplay -q -D hw:0,0 /tmp/tone-m.wav; wait $R
	python3 - "$1" <<'PY'
import math, struct, wave, sys
w = wave.open("/tmp/vc-rec.wav"); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack("<%dh" % (len(d) // 2), d)
def g(x, f=1000, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
print("%-9s before %6.1f  during %6.1f" % (sys.argv[1], g(s[2400:33600]), g(s[52800:120000])), file=sys.stderr)
PY
}
(
	echo 'set _verb "Voice Call"'; echo "set _enadev Earpiece"; echo "set _enadev Mic"; sleep 1.5
	python3 /tmp/voice-open.py hw:0,2 30 > /tmp/vo.log 2>&1 &
	sleep 2
	c "ADC1_MIXER Switch" 0; c "TX SMIC MUX0" ADC3; c "ADC4_MIXER Switch" 1; c "ADC4 MUX" INP5
	meas Earpiece
	echo "set _disdev Earpiece"; echo "set _enadev Speaker"; sleep 2
	meas Speaker
	echo "set _disdev Speaker"; echo "set _enadev Earpiece"; sleep 1
	meas Earpiece
	c "ADC4_MIXER Switch" 0; c "TX SMIC MUX0" ADC0; c "ADC1_MIXER Switch" 1
	sleep 1; echo 'set _verb HiFi'; sleep 1; echo reset
) | alsaucm -c hw:0 -b - 2>&1 | grep -v "^$"
sleep 1; pkill -f "voice-open.py" ; sleep 1; cat /tmp/vo.log | tr '\n' ' '; echo
