#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
# back to the normal greeter session
sudo rm -f /usr/local/share/applications/mobi.phosh.Phrog.desktop /usr/local/bin/phrog-debug-session
sudo cp /etc/phrog/greetd-config.toml.orig /etc/phrog/greetd-config.toml
grep ^command /etc/phrog/greetd-config.toml
real=$(cat $STATE)
sudo rc-service greetd restart >/dev/null 2>&1
sleep 20
pgrep -x phrog >/dev/null && echo "phrog up" || echo "phrog NOT up"
# fast swivel cycles in software
for step in 2 1 2 1 2 1 2; do
	echo $step | sudo tee $INJ >/dev/null
	sleep 3
done
sleep 4
sudo env $G grim -o DSI-1 -s 0.3 /tmp/r14-DSI-1.png
sudo env $G grim -o DSI-2 -s 0.3 /tmp/r14-DSI-2.png
pgrep -x phrog >/dev/null && echo "phrog alive after 7 swivel changes" || echo "phrog DEAD"
sudo dmesg | grep -E 'unhandled exception' | tail -2
# put the injected state back to what the sensors say
echo "$real" | sudo tee $INJ >/dev/null
sleep 3
echo "state back to $(cat $STATE)"
