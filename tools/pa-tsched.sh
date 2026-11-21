#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
line=$($E pactl list short modules | grep module-alsa-card | head -1)
id=$(echo "$line" | cut -f1)
args=$(echo "$line" | cut -f3)
echo "card module $id: $args"
new=$(echo "$args" | sed 's/tsched=yes/tsched=no/')
case "$new" in *tsched=no*) ;; *) new="$new tsched=no" ;; esac
new="$new fragments=4 fragment_size=3840"
$E pactl unload-module $id
$E pactl load-module module-alsa-card $new
sleep 2
$E pactl list short modules | grep module-alsa-card | cut -f3 | grep -o "tsched=[a-z]*\|fragment[a-z_]*=[0-9]*" | tr '\n' ' '; echo
python3 -c "open('/tmp/sil8k.raw','wb').write(b'\0\0' * 8000 * 2)"
for mode in 0 1; do
	$CA $mode >/dev/null; sleep 2
	echo "== $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
	t0=$(date +%s.%N)
	$E timeout 20 pacat --playback --raw --rate=8000 --channels=1 --format=s16le --latency-msec=60 < /tmp/sil8k.raw
	echo "   pacat 2.0 s at 8 kHz took $(echo "$(date +%s.%N) - $t0" | bc -l | cut -c1-5) s"
	$E timeout 3 parec --raw --rate=8000 --channels=1 --format=s16le --latency-msec=20 > /tmp/c.raw 2>/dev/null
	echo "   parec 3 s -> $(( $(stat -c %s /tmp/c.raw) / 16000 )).$(( $(stat -c %s /tmp/c.raw) % 16000 * 10 / 16000 )) s of audio"
	grep -E "period_size|buffer_size" /proc/asound/card0/pcm0p/sub0/hw_params | tr '\n' ' '; echo
done
$CA 0 >/dev/null
