#!/bin/sh
P=${1:-2}
sudo timeout 100 python3 -u /tmp/wdata.py - 2 ${2:-5} --dpm --v5 --noping --profile $P 2>&1 | grep -vE "\\$ (cat|ip addr flush|ip link set rmnet_data1 down|ip route)"
echo EXIT $?
