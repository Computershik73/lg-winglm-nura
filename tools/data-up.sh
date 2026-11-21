#!/bin/sh
# first mobile data connection through NetworkManager + ModemManager fork
sync
echo "uptime $(cut -d' ' -f1 /proc/uptime)"
cat /run/rmnet-ipa-data-format 2>/dev/null && echo " (formats already set)"
timeout 90 sudo nmcli connection up RUS 2>&1 | tail -2
sync
sudo logread | grep -E "ModemManager" | grep -iE "ipa|dpm|mux|link|data format|aggregation|error|fail|connect" | tail -25 | cut -c16-230
ip -d link show | grep -A2 "qmapmux" | grep -E "qmapmux|rmnet" | head -4
L=$(ip -br link | grep -o "qmapmux[0-9.]*" | head -1)
[ -n "$L" ] || { echo "no link"; exit 0; }
ip -br addr show dev $L; ip route | grep $L; nmcli -f GENERAL.STATE,IP4.DNS device show $L 2>/dev/null | head -4
sync
ping -c 4 -W 3 -I $L 1.1.1.1 | tail -2
sync
echo "rx/tx packets: $(cat /sys/class/net/$L/statistics/rx_packets)/$(cat /sys/class/net/$L/statistics/tx_packets)"
