#!/bin/sh
T=/var/log/winglm-volte.trace
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
n0=$(sudo wc -l < $T)
sudo rm -f /tmp/ims-call.pcap /tmp/lo-call.pcap
sudo tcpdump -i rmnet_data1 -n -s 200 -U -w /tmp/ims-call.pcap udp > /dev/null 2>&1 &
sudo tcpdump -i lo -n -s 100 -U -w /tmp/lo-call.pcap 'udp and not port 5070' > /dev/null 2>&1 &
echo "$(date +%T) watching for a call (up to ${1:-900} s)"
end=$(( $(date +%s) + ${1:-900} ))
while [ $(date +%s) -lt $end ]; do
	sudo tail -n +$((n0 + 1)) $T | grep -qE "MO call to|MT INVITE" && break
	sleep 1
done
sleep 8
echo "== $(date +%T) during the call"
$E pactl list cards | grep -E "Active Profile"
$E pactl list sink-inputs | grep -E "Sink Input|Sink:|application.name|media.role|Corked" | sed 's/^\s*//'
$E pactl list source-outputs | grep -E "Source Output|Source:|application.name|media.role|Corked" | sed 's/^\s*//'
for i in $(seq 1 600); do
	sudo tail -n +$((n0 + 1)) $T | grep -q "hangup\|MO call failed" && break
	sleep 1
done
sleep 6
sudo pkill -x tcpdump
sleep 1
echo "== $(date +%T) trace"
sudo tail -n +$((n0 + 1)) $T | grep -v "GNOME Calls REGISTER\|REGISTER sip\|(. REGISTER)\|IPsec\|tcp to"
echo "== IMS side RTP (rmnet_data1), by flow"
sudo tcpdump -r /tmp/ims-call.pcap -n 2>/dev/null | awk '{print $3, $4, $5}' | sed 's/\.[0-9]*\( \|:\)/ \1/' | sort | uniq -c | sort -rn | head -8
echo "== loopback RTP (Calls <-> gateway), by flow"
sudo tcpdump -r /tmp/lo-call.pcap -n 2>/dev/null | awk '{print $3, $4, $5}' | sort | uniq -c | sort -rn | head -8
