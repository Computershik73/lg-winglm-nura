#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
python3 -c "
import struct
open('/tmp/sil8k.raw','wb').write(b'\0\0' * 8000 * 2)
open('/tmp/sil48k.raw','wb').write(b'\0\0' * 48000 * 2 * 2)
"
for mode in 0 1; do
	$CA $mode >/dev/null; sleep 2
	echo "== $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
	for spec in "8000 1 /tmp/sil8k.raw" "48000 2 /tmp/sil48k.raw"; do
		set -- $spec
		t0=$(date +%s.%N)
		$E timeout 20 pacat --playback --raw --rate=$1 --channels=$2 --format=s16le --latency-msec=60 < $3
		t1=$(date +%s.%N)
		echo "   pacat 2.0 s at $1 Hz ${2}ch took $(echo "$t1 - $t0" | bc -l | cut -c1-5) s"
	done
	grep -E "^(state|hw_ptr|appl_ptr)" /proc/asound/card0/pcm0p/sub0/status 2>/dev/null | tr '\n' ' '; echo
	cat /proc/asound/card0/pcm0p/sub0/hw_params 2>/dev/null | tr '\n' ' '; echo
done
$CA 0 >/dev/null
