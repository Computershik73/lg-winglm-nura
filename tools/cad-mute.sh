#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
grep -iE "warning:" /tmp/callaudiod-abuild.log | cut -c1-160
pkill -u user -x callaudiod; sleep 1
$E G_MESSAGES_DEBUG=all setsid /usr/bin/callaudiod > /tmp/cad.log 2>&1 < /dev/null &
sleep 2
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:3 int32:4 uint32:0; sleep 2
$E callaudiocli -u 1 >/dev/null 2>&1; sleep 1
$E callaudiocli -u 0 >/dev/null 2>&1; sleep 1
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0; sleep 1
$E callaudiocli -m 0 >/dev/null 2>&1; sleep 2
grep -E "Voice Tx Mute|alsa card|muting|unmuting" /tmp/cad.log | cut -c1-140
pkill -u user -x callaudiod
