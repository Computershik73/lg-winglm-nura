#!/bin/sh
R=/home/user/.local/share/abuild/aports
args=""; for p in $(apk info 2>/dev/null | grep -E '^(phosh|libphosh)' | sort -u); do [ -f $R/aarch64/$p-0.58.0-r25.apk ] && args="$args $p=0.58.0-r25"; done
sudo apk add --no-network --repository $R $args 2>&1 | tail -1
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r22.apk /tmp/device-lg-winglm-phosh-1-r22.apk /tmp/device-lg-winglm-dsp-1-r22.apk 2>&1 | tail -1
apk info -v 2>/dev/null | grep -E "^(phosh-0|device-lg-winglm-1|device-lg-winglm-dsp)"
# boot-like: everything Bluetooth blocked (as after bt_power registers), bluetoothd before hci0 exists
sudo rc-service bluetooth stop >/dev/null 2>&1; sudo rc-service winglm-bt stop >/dev/null 2>&1; sleep 1
sudo python3 /tmp/rfkill-all.py block; sleep 1
echo "blocked: $(for r in /sys/class/rfkill/*; do printf '%s=%s ' $(cat $r/name) $(cat $r/soft); done)"
sudo rc-service winglm-bt start >/dev/null 2>&1; sudo rc-service bluetooth start >/dev/null 2>&1
sleep 12
echo "after: $(for r in /sys/class/rfkill/*; do printf '%s=%s ' $(cat $r/name) $(cat $r/soft); done)"
sudo tail -4 /var/log/winglm-bt.log
bluetoothctl show | grep -E "Powered"
