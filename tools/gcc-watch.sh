#!/bin/sh
# wait (up to 15 min) for gnome-control-center to start, attach gdb, save the
# backtrace of a crash to /tmp/gcc-gdb.txt; the started instance from my
# earlier test is gone (timeout killed it)
OUT=/tmp/gcc-gdb.txt
echo "watch started $(date)" > $OUT
end=$(( $(date +%s) + 900 ))
while [ $(date +%s) -lt $end ]; do
	P=$(pgrep -n -x gnome-control-c)
	[ -z "$P" ] && P=$(pgrep -n -f '^/usr/bin/gnome-control-center')
	if [ -n "$P" ]; then
		echo "attach $P $(date +%T)" >> $OUT
		gdb -q -batch -p $P -ex 'set pagination off' -ex 'handle SIGPIPE SIG32 SIG33 SIG34 SIG35 nostop noprint pass' \
			-ex continue -ex 'echo \n=== CRASH ===\n' -ex 'info signal' -ex 'thread apply all bt 40' >> $OUT 2>&1
		echo "gdb done $(date +%T)" >> $OUT
		exit 0
	fi
	usleep 30000 2>/dev/null || sleep 0.03
done
echo "timeout $(date)" >> $OUT
