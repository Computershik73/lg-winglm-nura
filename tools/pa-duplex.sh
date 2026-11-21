#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
cnt() {
python3 - "$1" <<'PY'
import sys, struct
d = open(sys.argv[1], 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print('%.2f s captured, RMS %d' % (len(s) / 8000.0, int((sum(v*v for v in s) / max(1, len(s))) ** 0.5)))
PY
}
for mode in 0 1; do
	$CA $mode >/dev/null; sleep 2
	echo "== mode $mode: $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
	SRC=$($E pactl get-default-source)
	# capture only
	$E timeout 3 parec -d "$SRC" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/cap-only.raw 2>/tmp/cap.err
	echo "capture alone: $(cnt /tmp/cap-only.raw) $(head -1 /tmp/cap.err)"
	# capture while playing
	$E paplay --property=media.role=phone /tmp/tone1k.wav &
	sleep 0.3
	$E timeout 3 parec -d "$SRC" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/cap-duplex.raw 2>/tmp/cap.err
	echo "capture while playing: $(cnt /tmp/cap-duplex.raw) $(head -1 /tmp/cap.err)"
	wait
	for p in pcm0p pcm1c; do echo "  $p: $(head -1 /proc/asound/card0/$p/sub0/status)"; done
done
$CA 0 >/dev/null
sudo dmesg | tail -15 | grep -iE "asoc|dpcm|q6|afe|adm|error|fail" | cut -c1-160
