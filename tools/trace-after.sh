#!/bin/sh
# usage: trace-after.sh START_LINE [WAIT_REGEX] [SECONDS]
# prints trace lines from START_LINE on (no GNOME Calls keepalives), waiting
# up to SECONDS until WAIT_REGEX shows; START_LINE "last" = the last daemon start
F=/var/log/winglm-volte.trace
L=$1; W=${2:-'IMS registered|link down|Traceback'}; S=${3:-0}
[ "$L" = last ] && L=$(sudo grep -naE "IPA: DPM open port|waiting for GNOME Calls" $F | tail -2 | head -1 | cut -d: -f1)
echo "from line $L of $(sudo wc -l < $F)"
end=$(( $(date +%s) + S ))
while :; do
	new=$(sudo tail -n +$L $F | grep -av "GNOME Calls REGISTER")
	echo "$new" | grep -aqE "$W" && break
	[ $(date +%s) -ge $end ] && break
	sleep 5
done
echo "$new" | cut -c1-200 | tail -40
cat /run/winglm-volte/status
