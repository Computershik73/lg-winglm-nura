#!/bin/sh
Q="sudo timeout 30 qmicli -d qrtr://0"
N0=$(dmesg | wc -l)
sudo rc-service winglm-modem restart 2>&1 | tail -2
sleep 40
dmesg | tail -n +$N0 | grep -iE "subsys|mpss|modem.*(power|boot|shut|start)|pil" | head -8 | cut -c1-140
for s in /sys/bus/msm_subsys/devices/*; do echo "$(cat $s/name)=$(cat $s/state)"; done | grep -E "modem|adsp"
$Q --dms-get-operating-mode 2>&1 | tail -2
$Q --pdc-list-configs=platform 2>&1 | grep -B1 "Active" | grep Description
$Q --uim-get-card-status 2>&1 | grep -E "Card state|Application state" | head -3
