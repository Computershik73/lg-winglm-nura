#!/bin/sh
# Open Settings > Wi-Fi in the session, focus the search entry by tapping, check stevia stays alive
E="env -i HOME=/home/user $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<0>" >/dev/null 2>&1
SP=$(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1); echo "stevia pid before: $SP"
pkill -u user -x gnome-control-c 2>/dev/null; sleep 1
$E setsid gnome-control-center wifi > /tmp/gcc.log 2>&1 < /dev/null &
sleep 8
$E wlr-randr | grep -E '^DSI|Position|Transform|Enabled' | tr '\n' ' '; echo
$E grim -o DSI-1 -s 0.3 /tmp/gcc-1.png; $E grim -o DSI-2 -s 0.3 /tmp/gcc-2.png
echo "stevia pid after open: $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1)"
chmod 644 /tmp/gcc-*.png
