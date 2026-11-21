#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -f "python3 /tmp/winglm-call-volume"
$E setsid python3 /tmp/winglm-call-volume > /tmp/cv.log 2>&1 < /dev/null &
sleep 2
g() { echo "RX0=$(amixer -c 0 cget 'name=RX_RX0 Digital Volume' | sed -n 's/.*: values=//p')"; }
sig() { sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/4 org.freedesktop.ModemManager1.Call.StateChanged int32:$1 int32:$2 uint32:0; }
$E pactl set-sink-volume @DEFAULT_SINK@ 70%
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2; echo "call mode, no voice yet, 70%: $(g)"
sig 0 1; sleep 3; echo "dialing (voice session up): $(g)"
$E pactl set-sink-volume @DEFAULT_SINK@ 100%; sleep 1.5; echo "100%: $(g)"
$E pactl set-sink-volume @DEFAULT_SINK@ 40%; sleep 1.5; echo "40%: $(g)"
sig 1 7; sleep 1
$E callaudiocli -m 0 >/dev/null 2>&1; sleep 3; echo "after call: $(g)"
$E pactl set-sink-volume @DEFAULT_SINK@ 70%
sleep 3; cat /tmp/cv.log
