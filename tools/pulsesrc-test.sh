#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
UID_=$(id -u user)
R="sudo env PULSE_SERVER=unix:/run/user/$UID_/pulse/native PULSE_COOKIE=/home/user/.config/pulse/cookie"
m() {
	who=$1; shift
	t0=$(date +%s.%N)
	$who timeout 8 gst-launch-1.0 -q -e $* ! audioconvert ! audioresample ! audio/x-raw,format=S16LE,rate=8000,channels=1 ! filesink location=/tmp/ps.raw > /tmp/ps.out 2>&1
	rc=$?
	t1=$(date +%s.%N)
	printf '   %-6s %-55s rc=%d %s bytes in %.1f s %s\n' "$(echo $who | cut -c1-6)" "$*" $rc "$(stat -c %s /tmp/ps.raw 2>/dev/null)" "$(echo "$t1 - $t0" | bc)" "$(grep -iE 'error|warn' /tmp/ps.out | head -1 | cut -c1-80)"
	sudo rm -f /tmp/ps.raw
}
m "$E" pulsesrc num-buffers=100
m "$R" pulsesrc num-buffers=100
m "$R" pulsesrc num-buffers=100 "stream-properties=props,media.role=phone"
m "$R" pulsesrc num-buffers=100 "stream-properties=props,media.role=phone,filter.suppress=echo-cancel"
