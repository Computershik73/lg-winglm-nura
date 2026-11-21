#!/bin/sh
# usage: wait-challenge.sh START_LINE SECONDS
# waits for the network's 401 to a re-REGISTER and what follows, or a failure
F=/var/log/winglm-volte.trace
L=$1; S=$2
end=$(( $(date +%s) + S ))
while :; do
	new=$(sudo tail -n +$L $F | grep -av "GNOME Calls REGISTER")
	if echo "$new" | grep -aq "re-REGISTER challenged"; then
		sleep 40
		new=$(sudo tail -n +$L $F | grep -av "GNOME Calls REGISTER")
		break
	fi
	echo "$new" | grep -aqE "link down|Traceback|error handling" && break
	[ $(date +%s) -ge $end ] && break
	sleep 20
done
echo "$new" | grep -aE "REGISTER|registered|link down|Traceback|Error|error|challenged|IPsec|tcp|Min-Expires|stopping" | tail -40 | cut -c1-180
echo "refreshes answered 200: $(echo "$new" | grep -ac "IMS registered")"
cat /run/winglm-volte/status
