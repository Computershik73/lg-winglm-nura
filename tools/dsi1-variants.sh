#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
PP=$(pgrep -u user -x phosh)
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
alive() { [ "$(pgrep -u user -x phosh)" = "$PP" ] && echo "  ok" || { echo "  PHOSH GONE"; grep -vE "^\[New Thread|^\[Thread|Reading symbols|^$|warning: |Download|debuginfod|LWP" /tmp/phosh-gdb.log | grep -E "^#|CRITICAL|signal|exited" | head -25 | cut -c1-200; exit 1; }; }
r() { $E wlr-randr "$@"; }
pos2() { r --output DSI-2 --on --pos 230,360 --scale 3; }
echo "1 locked, DSI-1 off/on"; sudo loginctl lock-session $SES; sleep 2; r --output DSI-1 --off; sleep 3; r --output DSI-1 --on --transform 90; sleep 3; pos2; sleep 3; alive
sudo loginctl unlock-session $SES; sleep 2
echo "2 overview open, DSI-1 off/on"; $E wtype -M logo -k a -m logo 2>/dev/null; sleep 2; r --output DSI-1 --off; sleep 3; r --output DSI-1 --on --transform 90; sleep 3; pos2; sleep 3; alive
echo "3 locked, DSI-1 off then DSI-2 off, both on"; sudo loginctl lock-session $SES; sleep 2; r --output DSI-1 --off; sleep 1.5; r --output DSI-2 --off; sleep 3; r --output DSI-1 --on --transform 90; sleep 1; pos2; sleep 4; alive
echo "4 DSI-1 off quickly after a DSI-2 change"; pos2; r --output DSI-1 --off; sleep 0.3; r --output DSI-1 --on --transform 90; sleep 0.3; pos2; sleep 4; alive
sudo loginctl unlock-session $SES
