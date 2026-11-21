#!/bin/sh
# stop a leftover call-real-in.sh run (cmdline "sh -s 1700"); this script runs as "sh -s"
for p in $(pgrep -x sh); do
	c=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null)
	case "$c" in
	"sh -s 1700 "|"sh -s 1700") echo "killing $p: $c"; kill $p ;;
	esac
done
sleep 1
echo "left: $(for p in $(pgrep -x sh); do tr '\0' ' ' < /proc/$p/cmdline; echo; done | grep -c '1700')"
mmcli -m any --voice-list-calls 2>&1 | tail -3
uptime
