#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/3 org.freedesktop.ModemManager1.Call.StateChanged int32:3 int32:4 uint32:0; sleep 2
echo "voice PCM $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
N0=$(dmesg | wc -l)
for g in 1 3 5; do python3 /tmp/ctl3.py "Voice Rx Gain" $g; sleep 0.5; done
python3 /tmp/ctl3.py "Voice Rx Gain" 3 0x11C05000
sleep 0.5
dmesg | tail -n +$N0 | grep -viE "tfa" | head -8 | cut -c1-150
amixer -c 0 controls | grep -iE "MI2S.*Vol|PRI.*Gain|AFE.*Vol|Internal.*Vol|MultiMedia1.*Vol|Voice.*Vol" | head -8
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/3 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0; sleep 1
$E callaudiocli -m 0 >/dev/null 2>&1
