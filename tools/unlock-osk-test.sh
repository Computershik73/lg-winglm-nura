#!/bin/sh
# Unlock the user session via logind, show the OSK over DBus, screenshot both screens
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
S=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
echo "session $S"
sudo loginctl unlock-session "$S"
sleep 3
$E grim -o DSI-1 -s 0.25 /tmp/ul-DSI-1.png
$E grim -o DSI-2 -s 0.35 /tmp/ul-DSI-2.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true >/dev/null
sleep 2
$E grim -o DSI-2 -s 0.35 /tmp/ul-osk-DSI-2.png
$E grim -o DSI-1 -s 0.25 /tmp/ul-osk-DSI-1.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null
chmod 644 /tmp/ul-*.png
