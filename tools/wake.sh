#!/bin/sh
# Wake the screens of the user session and keep them on while testing
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
for p in $(pgrep -x grim); do kill $p; done
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<0>" 2>&1 | grep -v '^()$'
if ! pgrep -f 'gnome-session-inhibit --inhibit idle' >/dev/null; then
	$E setsid gnome-session-inhibit --inhibit idle --reason "winglm tests" sleep 14400 >/dev/null 2>&1 < /dev/null &
fi
sleep 3
$E wlr-randr | grep -E '^DSI|Enabled'
pgrep -af 'gnome-session-inhibit' | grep -v pgrep | cut -c1-80
