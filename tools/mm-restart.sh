#!/bin/sh
P=$(pidof ModemManager); [ -n "$P" ] && sudo kill $P
sleep 2
sudo rc-service modemmanager start 2>&1 | tail -2
for i in $(seq 1 30); do
	M=$(mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | head -1 | cut -d/ -f2)
	[ -n "$M" ] && st=$(mmcli -m $M 2>/dev/null | grep -E "^\s*Status\s*\|\s*state" | sed "s/.*state: //") && echo "+${i}x5s: $st"
	case "$st" in *registered*|*connected*|*enabled*|*failed*) break;; esac
	sleep 5
done
mmcli -m $M 2>&1 | grep -E "state|power|access tech|signal quality|operator name|registration|own" | head -12
