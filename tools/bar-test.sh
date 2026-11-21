#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
PP=$(pgrep -u user -x phosh)
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<0>" >/dev/null
sudo loginctl unlock-session $SES; sleep 3
echo "locked: $($E gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive)"
shot() { $E grim -o DSI-1 -s 0.5 /tmp/$1-1.png; $E grim -o DSI-2 -s 0.5 /tmp/$1-2.png; chmod 644 /tmp/$1-*.png; }
shot b0
sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1232 540 800 300 20; sleep 2; shot b1
sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1205 540 1239 200 10; sleep 2; shot b2
sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2; shot b3
sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2; shot b4
echo "phosh same: $([ "$(pgrep -u user -x phosh)" = "$PP" ] && echo yes || echo NO)  osk visible: $($E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible)"
