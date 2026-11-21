#!/bin/sh
# measure what the earpiece really emits with the top microphone next to it
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
python3 - <<'PY'
import math, struct
def tone(path, rate, db, secs):
    a = 32767 * 10 ** (db / 20.0) * math.sqrt(2)
    open(path, 'wb').write(b''.join(struct.pack('<h', int(a * math.sin(2 * math.pi * 1000 * i / rate))) for i in range(int(rate * secs))))
tone('/tmp/t8k.raw', 8000, -24, 2.0)
PY
$CA 1 >/dev/null; sleep 2
echo "profile: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
# top mic (amic5 -> ADC4) instead of the main mic
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC3
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 1; amixer -c 0 -q cset "name=ADC4 MUX" INP5
$E parec --raw --rate=8000 --channels=1 --format=s16le --latency-msec=20 > /tmp/ear.raw 2>/dev/null &
R=$!
sleep 2                                            # 0-2 s: silence
$E pacat --playback --raw --rate=8000 --channels=1 --format=s16le --latency-msec=60 --property=media.role=phone < /tmp/t8k.raw
sleep 1                                            # gap
$E pacat --playback --raw --rate=8000 --channels=1 --format=s16le --latency-msec=60 < /tmp/t8k.raw   # no role
sleep 1
kill $R
amixer -c 0 -q cset "name=ADC4_MIXER Switch" 0; amixer -c 0 -q cset "name=TX SMIC MUX0" ADC0
amixer -c 0 -q cset "name=ADC1_MIXER Switch" 1
$CA 0 >/dev/null
python3 - <<'PY'
import struct
d = open('/tmp/ear.raw', 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print('top mic RMS per 0.5 s:', [int((sum(v*v for v in s[k:k+4000]) / max(1, len(s[k:k+4000]))) ** 0.5) for k in range(0, len(s), 4000)])
PY
