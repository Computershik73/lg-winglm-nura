#!/bin/sh
sudo qmicli -d qrtr://0 --link-add=iface=rmnet_ipa0,prefix=qmaptest,mux-id=9,flags=ingress-map-cksumv5 2>&1 | tail -4
ip -d link show | grep -A3 "qmaptest" | head -8
sudo qmicli -d qrtr://0 --link-list=rmnet_ipa0 2>&1 | tail -4
L=$(ip -br link | grep -o "qmaptest[0-9.]*" | head -1)
[ -n "$L" ] && sudo qmicli -d qrtr://0 --link-delete=link-iface=$L,mux-id=9 2>&1 | tail -2
ip -br link | grep -E "rmnet|qmap"
