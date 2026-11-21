#!/bin/sh
# usage: sh -s OUT LX LY NAME [WAIT]  - genuine touch tap at logical coords of output OUT (DSI-1 landscape T or DSI-2), screenshots
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
OUT=$1; LX=$2; LY=$3; N=${4:-tt}; W=${5:-2}
if [ "$OUT" = DSI-1 ]; then
	TF=$($E wlr-randr | awk '/^DSI-1/{f=1} f&&/Transform/{print $2; exit}')
	if [ "$TF" = 90 ]; then RX=$((LY*3)); RY=$((2460-LX*3)); else RX=$((LX*3)); RY=$((LY*3)); fi
	sudo python3 /tmp/ti.py tap /dev/input/event4 $RX $RY
else
	sudo python3 /tmp/ti.py tap /dev/input/event6 $((LX*3)) $((LY*3))
fi
sleep $W
$E grim -o DSI-1 -s 0.5 /tmp/$N-1.png; $E grim -o DSI-2 -s 0.5 /tmp/$N-2.png; chmod 644 /tmp/$N-*.png
