#!/bin/sh
# usage: sh -s X Y [shot-name]  - click at logical X,Y (global layout coords), wait, screenshot both screens
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E wlrctl pointer move -5000 -5000
$E wlrctl pointer move $1 $2
sleep 0.3
$E wlrctl pointer click left
sleep ${4:-2}
N=${3:-tap}
$E grim -o DSI-1 -s 0.5 /tmp/$N-1.png; $E grim -o DSI-2 -s 0.5 /tmp/$N-2.png
chmod 644 /tmp/$N-*.png
echo "stevia: $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1)"
