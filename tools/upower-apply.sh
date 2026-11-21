#!/bin/sh
# test deploy of the UPower IgnoreLid drop-in (packaged next build)
sudo install -Dm644 /tmp/90-winglm-upower.conf /etc/UPower/UPower.conf.d/90-winglm.conf
sudo pkill -x upowerd; echo "upowerd stopped"
sleep 2
gdbus call --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower \
	--method org.freedesktop.DBus.Properties.GetAll org.freedesktop.UPower 2>&1 | tr ',' '\n' | grep -i lid
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
cat /sys/class/drm/card0-DSI-2/enabled
$E gsettings get org.gnome.Settings last-panel
pkill -x gnome-control-c
$E timeout 25 gdb -q -batch -ex 'set pagination off' -ex 'handle SIGPIPE SIG32 SIG33 SIG34 SIG35 nostop noprint pass' \
	-ex run -ex 'echo \n=== STOP ===\n' -ex 'bt 6' --args /usr/bin/gnome-control-center > /tmp/gcc-run-fix.txt 2>&1
echo "gdb exit $? (124 = still running after 25 s, no crash)"
grep -aE 'SIGSEGV|=== STOP|^#[0-9]|CRITICAL' /tmp/gcc-run-fix.txt | head -8 | cut -c1-160
