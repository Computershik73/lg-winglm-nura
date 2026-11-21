#!/bin/bash
# Run a command script in the pmOS initramfs telnet debug shell and print the
# output between markers. usage: tn.sh <script-file> [seconds]
f="$1"; t="${2:-15}"
{
	sleep 1
	echo 'echo ===BEGIN==='
	cat "$f"
	echo 'echo ===END==='
	sleep "$t"
} | timeout $((t + 5)) nc 172.16.42.1 23 2>/dev/null | tr -d '\r' | LC_ALL=C sed 's/[^[:print:]\t]//g' |
	sed -n '/^===BEGIN===$/,/^===END===$/p'
