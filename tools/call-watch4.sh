#!/bin/sh
T=/var/log/winglm-volte.trace
n0=$(sudo wc -l < $T)
c0=$(wc -l < /tmp/calls-debug.log)
echo "$(date +%T) watching for a call (up to ${1:-900} s)"
end=$(( $(date +%s) + ${1:-900} ))
while [ $(date +%s) -lt $end ]; do
	sudo tail -n +$((n0 + 1)) $T | grep -qE "echo test call|MO call to|MT INVITE" && break
	sleep 1
done
sleep 6
echo "== $(date +%T) udp sockets of gnome-calls (local:port rx_queue drops)"
P=$(pgrep -u user -x gnome-calls)
for ino in $(ls -l /proc/$P/fd 2>/dev/null | grep -o 'socket:\[[0-9]*\]' | grep -o '[0-9]*'); do
	awk -v i=$ino '$10==i {split($2,a,":"); printf "%d.%d.%d.%d:%d rxq=%d drops=%s\n", strtonum("0x" substr(a[1],7,2)), strtonum("0x" substr(a[1],5,2)), strtonum("0x" substr(a[1],3,2)), strtonum("0x" substr(a[1],1,2)), strtonum("0x" a[2]), strtonum("0x" substr($5, index($5,":")+1)), $13}' /proc/net/udp
done
for i in $(seq 1 600); do
	sudo tail -n +$((n0 + 1)) $T | grep -q "hangup\|MO call failed" && break
	sleep 1
done
sleep 2
echo "== $(date +%T) trace"
sudo tail -n +$((n0 + 1)) $T | grep -v "GNOME Calls REGISTER\|REGISTER sip\|(. REGISTER)\|IPsec\|tcp to"
echo "== calls debug (filtered)"
tail -n +$((c0 + 1)) /tmp/calls-debug.log | grep -iE "media|pipeline|codec|rtp|udp|pulse|link|error|warn|crit|state|sdp|port" | grep -viE "dbus|folks|evolution" | cut -c1-230 | head -80
