#!/bin/sh
# runs as greetd with the session environment
/usr/sbin/phrog > /dev/null 2>&1 &
pid=$!
sleep 1.2
if kill -0 $pid 2>/dev/null; then
	grep -oE '/[^ ]*(gallium|vulkan|EGL|GLES|epoxy)[^ ]*' /proc/$pid/maps | sort -u
	kill $pid
else
	echo "died before check"
fi
