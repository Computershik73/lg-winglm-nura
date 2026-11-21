#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -f "python3 /tmp/winglm-call-volume"
g() { amixer -c 0 cget "name=$1" | sed -n 's/.*: values=//p'; }
N0=$(dmesg | wc -l)
echo "idle: set 70 -> $(amixer -c 0 cset 'name=RX_RX0 Digital Volume' 70 >/dev/null 2>&1; echo $?) read $(g 'RX_RX0 Digital Volume')"
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/5 org.freedesktop.ModemManager1.Call.StateChanged int32:3 int32:4 uint32:0; sleep 2
echo "voice up: set 70 -> $(amixer -c 0 cset 'name=RX_RX0 Digital Volume' 70 2>&1 | tail -1) read $(g 'RX_RX0 Digital Volume')"
$E paplay /tmp/tone-m.wav & P=$!; sleep 0.7
echo "media playing: set 72 -> $(amixer -c 0 cset 'name=RX_RX0 Digital Volume' 72 2>&1 | tail -1) read $(g 'RX_RX0 Digital Volume')"
wait $P
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/5 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0; sleep 1
$E callaudiocli -m 0 >/dev/null 2>&1; sleep 1
dmesg | tail -n +$N0 | grep -iE "rx_macro|digital|volume|regmap|wcd|bolero" | head -6 | cut -c1-150
amixer -c 0 cget 'name=RX_RX0 Digital Volume' | head -2
