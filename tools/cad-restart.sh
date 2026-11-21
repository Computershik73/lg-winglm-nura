#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --timeout 15 --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
ls /usr/share/dbus-1/services/ | grep -i callaudio
pkill -u user -x callaudiod; sleep 1
$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio \
	--method org.freedesktop.DBus.Properties.Get org.mobian_project.CallAudio AudioMode
echo "callaudiod: $(pgrep -u user -a callaudiod)"
python3 -c "open('/tmp/sil8k.raw','wb').write(b'\0\0' * 8000 * 2)"
for mode in 1 0; do
	t0=$(date +%s.%N); $CA $mode; echo "   SelectMode $mode took $(echo "$(date +%s.%N) - $t0" | bc -l | cut -c1-5) s"
	sleep 1
	echo "== $($E pactl list cards | grep 'Active Profile' | sed 's/^\s*//')"
	t0=$(date +%s.%N)
	$E timeout 20 pacat --playback --raw --rate=8000 --channels=1 --format=s16le --latency-msec=60 < /tmp/sil8k.raw
	echo "   pacat 2.0 s at 8 kHz took $(echo "$(date +%s.%N) - $t0" | bc -l | cut -c1-5) s"
	grep -E "period_size|buffer_size" /proc/asound/card0/pcm0p/sub0/hw_params | tr '\n' ' '; echo
done
