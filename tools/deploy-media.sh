#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sudo cp /tmp/volte/media.py /tmp/volte/volted.py /usr/lib/winglm-volte/
# PulseAudio back to its normal module set
$E pactl list short modules | grep -q module-filter-heuristics || $E pactl load-module module-filter-heuristics >/dev/null
$E pactl list short modules | grep -q module-filter-apply || $E pactl load-module module-filter-apply >/dev/null
echo "filter modules: $($E pactl list short modules | grep -c filter)"
# callaudiod alive?
t0=$(date +%s.%N)
$E timeout 10 gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio \
	--method org.freedesktop.DBus.Properties.Get org.mobian_project.CallAudio AudioMode
echo "callaudiod answered in $(echo "$(date +%s.%N) - $t0" | bc) s"
# Calls back as a normal session service (drop the debug instance)
pkill -u user -x gnome-calls; sleep 1
$E gdbus call --session --dest org.gnome.Calls --object-path /org/gnome/Calls --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
sudo rc-service winglm-volte restart 2>&1 | tail -1
for i in $(seq 1 90); do sudo tail -n 3 /var/log/winglm-volte.trace | grep -q "IMS registered" && break; sleep 2; done
sudo tail -n 3 /var/log/winglm-volte.trace
echo "calls: $(pgrep -u user -x gnome-calls)"
