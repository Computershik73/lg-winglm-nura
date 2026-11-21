#!/bin/sh
# timeline of a CS call: MM call states, VoiceMMode1 PCM state, callaudiod
# mode, UCM verb; 10 minutes, /tmp/ringback.log
OUT=/tmp/ringback.log
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
: > $OUT
dbus-monitor --system "type='signal',interface='org.freedesktop.ModemManager1.Call',member='StateChanged'" 2>/dev/null |
	while read -r line; do
		case "$line" in *int32*) echo "$(date +%T.%N | cut -c1-12) MM $line" >> $OUT ;; esac
	done &
DM=$!
end=$(( $(date +%s) + 600 ))
prev=
while [ $(date +%s) -lt $end ]; do
	p=$(grep -h '^state' /proc/asound/card0/pcm2p/sub0/status /proc/asound/card0/pcm2c/sub0/status 2>/dev/null | tr '\n' ' ')
	[ -z "$p" ] && p=closed
	m=$($E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio \
		--method org.freedesktop.DBus.Properties.Get org.mobian_project.CallAudio AudioMode 2>/dev/null | tr -dc '0-9')
	cur="pcm=[$p] callaudio-mode=$m"
	[ "$cur" != "$prev" ] && echo "$(date +%T.%N | cut -c1-12) $cur" >> $OUT
	prev=$cur
	sleep 0.2
done
kill $DM 2>/dev/null
