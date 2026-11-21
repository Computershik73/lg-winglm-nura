#!/bin/sh
sudo cat /var/log/winglm-vss.log
sudo rc-service winglm-modem restart >/dev/null 2>&1
t0=$(date +%s)
for i in $(seq 1 40); do
	a=$(sudo timeout 3 qmicli -d qrtr://0 --uim-get-card-status 2>/dev/null | grep -m1 "Application state" | sed "s/.*: //")
	[ "$a" = "'ready'" ] && echo "usim ready at +$(( $(date +%s) - t0 ))s" && break
	sleep 1
done
sudo cat /var/log/winglm-vss.log | tail -3
for i in $(seq 1 30); do
	M=$(mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | head -1 | cut -d/ -f2)
	if [ -n "$M" ]; then
		st=$(mmcli -m $M -K 2>/dev/null | grep "modem.generic.state " | sed "s/.*: //")
		case "$st" in registered|connected|failed) echo "MM state $st at +$(( $(date +%s) - t0 ))s"; break;; esac
	fi
	sleep 5
done
mmcli -m $M -K 2>/dev/null | grep -E "generic.state |state-failed-reason|access-technologies.value|signal-quality.value|operator-name|registration-state"
