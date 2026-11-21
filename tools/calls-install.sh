#!/bin/sh
# install patched Calls r1, set the dial pad screen, restart Calls in the session
R=$HOME/.local/share/abuild/aports/aarch64
cd $R && sudo apk add --allow-untrusted ./calls-51.1-r2.apk ./calls-lang-51.1-r2.apk 2>&1 | tail -2
apk info -v 2>/dev/null | grep -E '^calls-'
# setting for this test (the device package will ship it as an override)
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E gsettings set org.gnome.Calls dialpad-monitor 'DSI-2'
$E gsettings get org.gnome.Calls dialpad-monitor
# restart the Calls service (D-Bus activation keeps polkit/session context)
pkill -u user -x gnome-calls; sleep 2
$E gdbus call --session --dest org.gnome.Calls --object-path /org/gnome/Calls \
	--method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
sleep 3
pgrep -a -u user gnome-calls | cut -c1-80
cat /sys/class/drm/card0-DSI-2/enabled
