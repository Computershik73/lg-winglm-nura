#!/bin/sh
# Dump LG touch driver state, then record all input events for N seconds.
secs="${1:-25}"
for d in /sys/devices/virtual/input/lge_touch /sys/devices/virtual/input/lge_sub_touch; do
	[ -d "$d" ] || continue
	echo "== $d"
	for a in lpwg_notify lpwg_data ignore_event touch_dex_mode keyguard ime_status \
		incoming_call mfts power_ctrl film_status debug_option; do
		[ -r "$d/$a" ] && printf '%s: %s\n' "$a" "$(cat "$d/$a" 2>&1 | head -3 | tr '\n' ' ')"
	done
done
echo "== recording ${secs}s of input events (libinput)"
timeout "$secs" libinput debug-events > /tmp/li.txt 2>&1
grep -cE 'TOUCH_(DOWN|MOTION)' /tmp/li.txt | sed 's/^/touch events: /'
grep -E 'DEVICE_ADDED' /tmp/li.txt | awk '{print $1, $3, $4, $5}' | head -12
grep -E 'TOUCH_DOWN|POINTER|TABLET|KEYBOARD_KEY' /tmp/li.txt | head -12
echo "== driver log"
dmesg | grep -E '\[Touch\]' | grep -vi swivel | tail -6
