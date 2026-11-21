#!/bin/sh
# Speaker (TFA98xx on PRI_MI2S) plays 1 kHz while the handset mic records; check the tone in the recording
A="amixer -c 0 -q cset"
M=$(dmesg | wc -l)
# playback: MultiMedia1 -> PRI_MI2S_RX (deep-buffer-playback)
$A "name=PRI_MI2S_RX Audio Mixer MultiMedia1" 1
# capture: handset mic (amic1) -> TX_CDC_DMA_TX_3 -> MultiMedia2
$A "name=TX DEC0 MUX" SWR_MIC
$A "name=TX SMIC MUX0" ADC0
$A "name=TX_CDC_DMA_TX_3 Channels" One
$A "name=TX_AIF1_CAP Mixer DEC0" 1
$A "name=ADC1_MIXER Switch" 1
$A "name=ADC1 Volume" 6
$A "name=TX_DEC0 Volume" 84
$A "name=MultiMedia2 Mixer TX_CDC_DMA_TX_3" 1
# 1 kHz stereo tone, 3 s
python3 - <<'EOF'
import math, struct, wave
w = wave.open("/tmp/tone.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
frames = b"".join(struct.pack("<hh", v, v) for v in (int(8000 * math.sin(2 * math.pi * 1000 * i / 48000)) for i in range(48000 * 3)))
w.writeframes(frames); w.close()
EOF
arecord -D hw:0,1 -f S16_LE -c 1 -r 48000 -d 5 /tmp/mic.wav > /tmp/arecord.log 2>&1 &
sleep 0.8
aplay -D hw:0,0 /tmp/tone.wav > /tmp/aplay.log 2>&1; echo "aplay exit $?"
wait
echo "arecord: $(tail -1 /tmp/arecord.log)"; tail -2 /tmp/aplay.log
python3 - <<'EOF'
import math, struct, wave
try:
    w = wave.open("/tmp/mic.wav"); n = w.getnframes(); data = w.readframes(n); w.close()
except Exception as e:
    print("no recording:", e); raise SystemExit
s = struct.unpack("<%dh" % (len(data) // 2), data)
def goertzel(x, f, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / len(x)
seg = lambda a, b: s[int(a * 48000):int(b * 48000)]
rms = lambda x: math.sqrt(sum(v * v for v in x) / max(len(x), 1))
for name, (a, b) in (("before", (0.0, 0.7)), ("during", (1.2, 3.2)), ("after", (4.2, 4.9))):
    x = seg(a, b)
    print("%-6s rms %7.1f  1kHz %8.2f  700Hz %7.2f  1300Hz %7.2f" % (name, rms(x), goertzel(x, 1000), goertzel(x, 700), goertzel(x, 1300)))
EOF
echo "== dmesg"
dmesg | tail -n +$M | grep -viE 'CAM_|healthd|lge_battery|charger|batt|KONA Media1: ASoC: no backend|buffer already allocated|q6asm_callback|__q6asm_cmd' | tail -25 | cut -c1-170
