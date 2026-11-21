#!/bin/sh
# screen should be on now: record states and start Settings under gdb
pkill -f '^sh /tmp/gcc-wake.sh'
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
date +%T
$E timeout 5 wlr-randr | grep -E '^[A-Z]|Enabled|Position|Transform|Scale'
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.gnome.Mutter.DisplayConfig.GetCurrentState | sed 's/.*@a(iiduba(ssss)a{sv}) /logical: /; s/.*\], \[(/logical: [(/' | cut -c1-400
pkill -x gnome-control-c
$E timeout 40 gdb -q -batch -ex 'set pagination off' -ex 'handle SIGPIPE SIG32 SIG33 SIG34 SIG35 nostop noprint pass' \
	-ex run -ex 'echo \n=== STOP ===\n' -ex 'bt 12' --args /usr/bin/gnome-control-center > /tmp/gcc-run-on.txt 2>&1
echo "gdb exit $?"
grep -avE '^\[(New|Thread|LWP|Detaching)|^\[.*exited|DEBUG|INFO' /tmp/gcc-run-on.txt | tail -16 | cut -c1-200
