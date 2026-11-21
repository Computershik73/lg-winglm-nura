#!/bin/sh
# Toggle Bluetooth the way the shell's quick setting does (gsd-rfkill BluetoothAirplaneMode)
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
gp() { $E gdbus call --session --dest org.gnome.SettingsDaemon.Rfkill --object-path /org/gnome/SettingsDaemon/Rfkill --method org.freedesktop.DBus.Properties.Get org.gnome.SettingsDaemon.Rfkill $1 | tr -d '()<>,'; }
sp() { $E gdbus call --session --dest org.gnome.SettingsDaemon.Rfkill --object-path /org/gnome/SettingsDaemon/Rfkill --method org.freedesktop.DBus.Properties.Set org.gnome.SettingsDaemon.Rfkill BluetoothAirplaneMode "<$1>" >/dev/null; }
st() { echo "  airplane=$(gp BluetoothAirplaneMode) hasBT=$(gp BluetoothHasAirplaneMode) rfkill: $(for r in /sys/class/rfkill/*; do printf '%s=%s ' $(cat $r/name) $(cat $r/soft); done) $(bluetoothctl show 2>/dev/null | grep -o 'Powered: ..*' | head -1)"; }
echo now:; st
echo off:; sp true; sleep 4; st
echo on:; sp false; sleep 9; st
tail -2 /var/log/winglm-bt.log /tmp/winglm-bt.log 2>/dev/null | tail -2
