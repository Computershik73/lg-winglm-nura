#!/bin/sh
# usage: wait-reg.sh START_LINE COUNT SECONDS
# waits until COUNT "IMS registered" lines (or a failure) appear after START_LINE
F=/var/log/winglm-volte.trace
L=$1; N=$2; S=$3
end=$(( $(date +%s) + S ))
while :; do
	new=$(sudo tail -n +$L $F | grep -av "GNOME Calls REGISTER")
	n=$(echo "$new" | grep -ac "IMS registered")
	[ "$n" -ge "$N" ] && break
	echo "$new" | grep -aqE "link down|Traceback|error handling" && break
	[ $(date +%s) -ge $end ] && break
	sleep 10
done
echo "$new" | grep -aE "REGISTER|registered|link down|Traceback|Error|error|new registration|IPsec|tcp|Min-Expires|stopping|waiting" | cut -c1-180
cat /run/winglm-volte/status
