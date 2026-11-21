#!/bin/sh
# Click the move button on the foot card (overview open), then check both screens
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E wlrctl pointer move -5000 -5000
$E wlrctl pointer move 752 320
sleep 0.5
$E wlrctl pointer click left
sleep 3
$E grim -o DSI-1 -s 0.5 /tmp/mv-3-DSI-1.png; $E grim -o DSI-2 -s 0.5 /tmp/mv-3-DSI-2.png
# move it back the same way: overview, click the button again
$E wtype -M logo -k a -m logo; sleep 2
$E grim -o DSI-1 -s 0.5 /tmp/mv-4-DSI-1.png; $E grim -o DSI-2 -s 0.5 /tmp/mv-4-DSI-2.png
$E wlrctl pointer move -5000 -5000
$E wlrctl pointer move 752 320
sleep 0.5
$E wlrctl pointer click left
sleep 3
$E grim -o DSI-1 -s 0.5 /tmp/mv-5-DSI-1.png; $E grim -o DSI-2 -s 0.5 /tmp/mv-5-DSI-2.png
# park the pointer on the main screen
$E wlrctl pointer move -5000 -5000
chmod 644 /tmp/mv-*.png
