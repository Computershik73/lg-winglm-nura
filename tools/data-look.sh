#!/bin/sh
mmcli -m any | grep -iE "ports|primary|drivers|plugin|bearer|revision|model" | sed 's/^ *//'
mmcli -m any -K | grep -E "modem.generic.(ports|bearers|drivers)|3gpp.(initial-eps|packet-service|eps)" | head -20
echo "== profiles"
mmcli -m any --3gpp-profile-manager-list 2>&1 | head -60
echo "== nm"
nmcli -t -f NAME,TYPE,DEVICE con show 2>&1 | head
nmcli -t dev 2>&1 | head
echo "== kernel rmnet"
zcat /proc/config.gz | grep -E "CONFIG_RMNET|CONFIG_IPA" | tr '\n' ' '; echo
ls /sys/class/net/rmnet_ipa0/ 2>&1 | tr '\n' ' '; echo
dmesg | grep -iE "rmnet|ipa_wwan|ipa3" | tail -8 | cut -c1-160
apk info -e modemmanager libqmi libmbim 2>/dev/null; apk info -v modemmanager 2>/dev/null
