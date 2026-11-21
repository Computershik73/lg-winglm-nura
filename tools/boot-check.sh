#!/bin/sh
sleep 30
echo "== services"; for s in qrtr-ns pd-mapper tqftpserv winglm-adsp winglm-rmtfs winglm-modem winglm-wlan modemmanager msm-firmware-loader; do printf '%-20s %s\n' $s "$(rc-service $s status 2>&1 | tail -1)"; done
echo "== mounts"; grep msm-firmware-loader /proc/mounts | awk '{print $2}'
echo "== subsystems"; for s in /sys/bus/msm_subsys/devices/*; do echo "$(cat $s/name): $(cat $s/state) $(cat $s/restart_level)"; done | grep -E 'adsp|modem|ipa'
echo "== sound"; cat /proc/asound/cards; sudo cat /sys/kernel/debug/tfa98xx-34/fw-state 2>/dev/null
echo "== wlan"; cat /var/log/winglm-wlan.log 2>/dev/null | tail -4; ip -br link | grep -E 'wlan0|rmnet'
cat /sys/class/net/wlan0/address 2>/dev/null
echo "== modem"; mmcli -L 2>&1 | head -3
