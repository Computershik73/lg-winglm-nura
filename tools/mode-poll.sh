#!/bin/sh
sudo rc-service winglm-modem restart >/dev/null 2>&1 &
t0=$(date +%s)
last=""
for i in $(seq 1 45); do
	m=$(sudo timeout 3 qmicli -d qrtr://0 --dms-get-operating-mode 2>/dev/null | sed -n "s/.*Mode: '\(.*\)'/\1/p")
	a=$(sudo timeout 3 qmicli -d qrtr://0 --uim-get-card-status 2>/dev/null | grep -m1 "Application state" | sed "s/.*: //")
	s="${m:-?} usim=${a:-?}"
	[ "$s" != "$last" ] && echo "+$(( $(date +%s) - t0 ))s: $s" && last=$s
	sleep 1
done
