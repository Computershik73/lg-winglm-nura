#!/bin/sh
# Lock, tap the keypad's keyboard button on DSI-2, screenshot, unlock via logind
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
sudo loginctl lock-session "$SES"; sleep 3
$E wlrctl pointer move -5000 -5000
$E wlrctl pointer move 321 669
sleep 0.5
$E wlrctl pointer click left
sleep 2
$E grim -o DSI-2 -s 0.35 /tmp/ol2-DSI-2.png
$E grim -o DSI-1 -s 0.25 /tmp/ol2-DSI-1.png
$E wlrctl pointer move -5000 -5000
sudo loginctl unlock-session "$SES"; sleep 2
chmod 644 /tmp/ol2-*.png
