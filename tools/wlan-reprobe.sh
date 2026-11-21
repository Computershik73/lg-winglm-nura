#!/bin/sh
# BDF daemon up, then restart the modem: WLAN FW comes back, icnss probes qcacld again (IPA ready now)
pgrep -f winglm-wlfw-bdf >/dev/null || sudo setsid python3 /tmp/winglm-wlfw-bdf > /tmp/wlfw-bdf.log 2>&1 < /dev/null &
sleep 1
for p in $(pgrep -f '^sleep 2147483647'); do sudo kill $p; done
sleep 6
sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 45
cat /tmp/wlfw-bdf.log
dmesg | tail -500 | grep -iE "icnss|hdd|wlan:|probe|wlan0|mac addr|cld|wma_" | grep -viE "CAM_" | tail -20 | cut -c1-170
ls /sys/class/net | tr '\n' ' '; echo
ip link show wlan0 2>&1 | head -2
