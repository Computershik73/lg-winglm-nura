#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
python3 - <<'PY'
import math, struct, wave
w = wave.open('/tmp/tone1k.wav', 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
w.writeframes(b''.join(struct.pack('<h', int(3000 * math.sin(2 * math.pi * 1000 * i / 8000))) for i in range(8000 * 4)))
w.close()
PY
$CA 1 >/dev/null; sleep 2
S=$($E pactl get-default-sink)
SRC=$($E pactl get-default-source)
echo "sink $S"; echo "source $SRC"
rms() {
python3 - "$1" <<'PY'
import sys, struct
d = open(sys.argv[1], 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print(len(s) / 8000.0, 's:', [int((sum(v*v for v in s[k:k+4000]) / max(1, len(s[k:k+4000]))) ** 0.5) for k in range(0, len(s), 4000)])
PY
}
for role in phone; do
	$E parec -d "$S.monitor" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/mon-$role.raw 2>/dev/null &
	P=$!
	sleep 0.5
	$E paplay --property=media.role=$role --property=filter.want=echo-cancel /tmp/tone1k.wav &
	sleep 1.5
	echo "-- role $role, streams while playing:"
	$E pactl list short sink-inputs
	$E pactl list short modules | grep -iE "echo" | cut -c1-120
	sleep 3.5
	kill $P; sleep 0.3
	echo "role $role -> earpiece sink monitor RMS per 0.5 s: $(rms /tmp/mon-$role.raw)"
done
$CA 0 >/dev/null
