#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
mon() {
	S=$($E pactl get-default-sink)
	$E timeout 2 parec -d "$S.monitor" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/m4.raw 2>/dev/null
	python3 - <<'PY'
import struct
d = open('/tmp/m4.raw', 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print('   monitor peak per 0.25 s:', [max([abs(v) for v in s[k:k+2000]] or [0]) for k in range(0, len(s), 2000)])
PY
}
echo "== A: call mode first, then the stream"
$CA 1 >/dev/null; sleep 2
$E gst-launch-1.0 -q audiotestsrc wave=ticks volume=0.4 is-live=true ! audio/x-raw,rate=16000,channels=1 ! pulsesink > /dev/null 2>&1 &
P=$!; sleep 1; mon; kill $P
$CA 0 >/dev/null; sleep 2
echo "== B: stream first (HiFi), then call mode"
$E gst-launch-1.0 -q audiotestsrc wave=ticks volume=0.4 is-live=true ! audio/x-raw,rate=16000,channels=1 ! pulsesink > /dev/null 2>&1 &
P=$!; sleep 1
$CA 1 >/dev/null; sleep 2
$E pactl list short sink-inputs
mon; kill $P
echo "== C: same with pacat"
$E sh -c 'python3 -c "
import math,struct,sys
for n in range(16000*6):
    v = int(8000*math.sin(2*math.pi*700*n/16000)) if (n % 16000) < 800 else 0
    sys.stdout.buffer.write(struct.pack(\"<h\", v))
" | pacat --raw --rate=16000 --channels=1 --format=s16le --latency-msec=40' &
sleep 1
$CA 0 >/dev/null; sleep 2; $CA 1 >/dev/null; sleep 2
mon
wait
$CA 0 >/dev/null
