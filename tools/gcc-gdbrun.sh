#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E gsettings get org.gnome.Settings last-panel
cat /sys/class/drm/card0-DSI-2/enabled
$E timeout 60 gdb -q -batch -ex 'set pagination off' -ex 'handle SIGPIPE SIG32 SIG33 SIG34 SIG35 nostop noprint pass' \
	-ex run -ex 'echo \n=== STOP ===\n' -ex 'bt 40' -ex 'info registers pc' --args /usr/bin/gnome-control-center > /tmp/gcc-run.txt 2>&1
echo "exit=$?"
grep -avE '^\[(New|Thread|LWP|Detaching)|^\[.*exited' /tmp/gcc-run.txt | grep -avE 'DEBUG|INFO' | tail -60 | cut -c1-230
