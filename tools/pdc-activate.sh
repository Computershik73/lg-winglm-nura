#!/bin/sh
# Select and activate a platform (HW) MBN on the modem (EFS = rmtfs copies)
NAME=${1:-SS_CDMALess-LA-Saipan}
Q="sudo timeout 30 qmicli -d qrtr://0"
ID=$($Q --pdc-list-configs=platform 2>&1 | awk -v n="Description: $NAME" 'index($0, n) {f=1} f && /ID:/ {print $2; exit}')
echo "config $NAME id $ID"
[ -n "$ID" ] || exit 1
N0=$(dmesg | wc -l)
$Q --pdc-activate-config="platform,$ID" 2>&1 | tail -2
sleep 50
dmesg | tail -n +$N0 | grep -iE "modem|mpss|subsys|ssr|restart|crash" | head -8 | cut -c1-140
for s in /sys/bus/msm_subsys/devices/*; do echo "$(cat $s/name)=$(cat $s/state)"; done | grep -E "modem|adsp"
$Q --dms-get-operating-mode 2>&1 | tail -2
$Q --pdc-list-configs=platform 2>&1 | grep -E "Description|Status"
$Q --uim-get-card-status 2>&1 | grep -E "Card state|Application state" | head -3
