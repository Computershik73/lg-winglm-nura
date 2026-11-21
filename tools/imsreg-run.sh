#!/bin/sh
cd /tmp
sudo rm -f /tmp/ims.pcap
sudo PCAP=/tmp/ims.pcap timeout 200 python3 -u /tmp/imsreg.py ${1:-10} 2>&1
echo EXIT $?
sleep 1
sudo pkill -x tcpdump
sleep 1
echo "== capture summary"
sudo tcpdump -r /tmp/ims.pcap -n -tt 2>/dev/null | awk '{t=$1; $1=""; print substr(t,7,8), $0}' | cut -c1-150 | head -40
