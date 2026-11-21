#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
echo "== settings state"
$E gsettings get org.gnome.Settings last-panel 2>&1
$E gsettings get org.gnome.Settings window-state 2>&1
pgrep -a -u user gnome-control 2>/dev/null
ulimit -c
echo "== run 30 s with debug"
$E G_MESSAGES_DEBUG=all timeout 30 gnome-control-center > /tmp/gcc.out 2>&1; echo "exit=$?"
grep -aiE 'critical|warning|error|assert|segfault|abort|signal|panel' /tmp/gcc.out | grep -v 'G_MESSAGES' | tail -40 | cut -c1-230
echo "== tail"
tail -8 /tmp/gcc.out | cut -c1-230
