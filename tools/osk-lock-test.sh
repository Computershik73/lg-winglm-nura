#!/bin/sh
# Lock, ask for the OSK, screenshot the small screen, unlock via logind
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
sudo loginctl lock-session "$SES"; sleep 3
echo "osk output: $($E gsettings get mobi.phosh.osk output)"
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true >/dev/null
sleep 2
$E grim -o DSI-2 -s 0.35 /tmp/ol-DSI-2.png
$E grim -o DSI-1 -s 0.25 /tmp/ol-DSI-1.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null
sudo loginctl unlock-session "$SES"; sleep 2
chmod 644 /tmp/ol-*.png
