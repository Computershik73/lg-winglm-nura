#!/bin/sh
# runs as greetd with the session environment
/usr/sbin/phrog > /tmp/phrog-run2.log 2>&1 &
pid=$!
for t in 2 5 10 20 30; do
	sleep $(( t - ${prev:-0} ))
	prev=$t
	if kill -0 $pid 2>/dev/null; then
		echo "t=${t}s alive ($(ps -o rss= -p $pid 2>/dev/null) kB)"
	else
		wait $pid; rc=$?
		echo "t=${t}s DEAD rc=$rc (signal $((rc - 128)) if >128)"
		break
	fi
done
kill $pid 2>/dev/null && echo "killed after test"
