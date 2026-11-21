#!/bin/sh
# second run in the same boot, with a TCP download over rmnet_data0
H=speedtest.tele2.net
IP=$(getent hosts $H | awk '{print $1}' | head -1)
echo "resolved $H -> $IP"
cat > /tmp/dl.sh <<EOF
ip route add $IP/32 dev rmnet_data0
curl -s --interface rmnet_data0 -o /dev/null -w "curl: %{http_code} %{size_download} bytes %{speed_download} B/s %{time_total}s\n" --max-time 25 http://$IP/10MB.zip -H "Host: $H"
ip route del $IP/32 dev rmnet_data0
EOF
sudo timeout 120 python3 -u /tmp/wdata.py internet 1 3 --dpm --v5 --count 10 --hook /tmp/dl.sh 2>&1 | grep -v "  tlv"
echo EXIT $?
cat /sys/class/net/rmnet_ipa0/statistics/rx_packets /sys/class/net/rmnet_ipa0/statistics/rx_dropped
sudo dmesg | grep -iE "rmnet|ipa" | tail -5 | cut -c1-160
