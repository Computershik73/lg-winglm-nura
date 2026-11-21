#!/bin/sh
# Launch foot, open the overview and screenshot the main screen at half logical size
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
apk info -e wlrctl >/dev/null || sudo env http_proxy=http://127.0.0.1:8888 https_proxy=http://127.0.0.1:8888 apk add wlrctl 2>&1 | tail -1
pgrep -u user -x foot >/dev/null || { $E setsid foot >/dev/null 2>&1 < /dev/null & sleep 4; }
$E grim -o DSI-1 -s 0.5 /tmp/mv-1-DSI-1.png; $E grim -o DSI-2 -s 0.5 /tmp/mv-1-DSI-2.png
$E wtype -M logo -k a -m logo; sleep 2
$E grim -o DSI-1 -s 0.5 /tmp/mv-2-DSI-1.png; $E grim -o DSI-2 -s 0.5 /tmp/mv-2-DSI-2.png
chmod 644 /tmp/mv-*.png
