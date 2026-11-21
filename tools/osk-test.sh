#!/bin/sh
# Show the OSK through its DBus interface in the user session and screenshot both screens
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
echo "locked: $($E gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive 2>&1)"
echo "osk output setting: $($E gsettings get mobi.phosh.osk output)"
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true >/dev/null
sleep 2
echo "visible: $($E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible)"
$E grim -o DSI-2 -s 0.35 /tmp/osk-DSI-2.png
$E grim -o DSI-1 -s 0.25 /tmp/osk-DSI-1.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null
chmod 644 /tmp/osk-*.png
