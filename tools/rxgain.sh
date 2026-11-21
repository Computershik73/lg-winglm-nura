#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/3 org.freedesktop.ModemManager1.Call.StateChanged int32:3 int32:4 uint32:0; sleep 2
echo "voice PCM $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
amixer -c 0 cget "name=Voice Rx Gain" | grep -E "type="
N0=$(dmesg | wc -l)
for g in 2 5; do amixer -c 0 cset "name=Voice Rx Gain" $g,4294967295,0 >/dev/null 2>&1; echo "Voice Rx Gain $g: exit $?"; sleep 0.5; done
dmesg | tail -n +$N0 | grep -iE "vol|gain|error|fail" | head -8 | cut -c1-150
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/3 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0; sleep 1
$E callaudiocli -m 0 >/dev/null 2>&1
