#!/bin/sh
nmcli -f IP4.ADDRESS,IP4.GATEWAY,IP6.ADDRESS,IP6.GATEWAY,GENERAL.IP-IFACE device show qrtr0 2>/dev/null
for t in "show dev wlan0" "show dev qmapmux0.3" "show dev lo" "show table local"; do
	timeout 5 ip -6 route $t >/dev/null 2>&1; echo "ip -6 route $t -> rc $?"
done
timeout 5 ip -6 route show table main >/dev/null 2>&1; echo "ip -6 route show table main -> rc $?"
sudo logread | grep -E "NetworkManager|routewrangler|nm-dispatcher" | grep -iE "qmapmux|qrtr0.*(route|gateway)|route.*fail|dispatcher.*50-winglm" | tail -10 | cut -c16-220
pgrep -a ip | grep route
