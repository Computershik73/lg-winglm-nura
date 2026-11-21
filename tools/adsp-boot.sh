#!/bin/sh
# qrtr-ns + pd-mapper, then boot the ADSP and look for the sound card
R=/home/user/.local/share/abuild/aports
sudo apk add --no-network --repository "$R" qrtr-ns qrtr-ns-openrc 2>&1 | grep -E 'Installing|ERROR' | tail -2
sudo rc-service qrtr-ns start 2>&1 | tail -1
sleep 1
sudo rc-service pd-mapper restart 2>&1 | tail -1
sleep 2
echo "== services before ADSP"; qrtr-lookup 2>&1 | head -20
M=$(dmesg | wc -l)
echo "== boot adsp"
echo 1 | sudo tee /sys/kernel/boot_adsp/boot >/dev/null
sleep 12
dmesg | tail -n +$M | grep -viE 'CAM_|healthd|lge_battery|qpnp_|charger|batt' | head -60 | cut -c1-180
echo "== state"
for s in /sys/bus/msm_subsys/devices/*; do echo "$(cat $s/name): $(cat $s/state)"; done | grep -E 'adsp|modem|cdsp'
cat /proc/asound/cards
echo "== services after ADSP"; qrtr-lookup 2>&1 | head -40
