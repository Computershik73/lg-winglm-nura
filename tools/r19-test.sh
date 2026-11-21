#!/bin/sh
# Install phosh r19 (greeter restarts with the WAYLAND_DEBUG wrapper still in
# place), open the swivel, count lockshields on DSI-2 and screenshot both screens.
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
sudo rm -f /tmp/phrog-wl.log
V=0.58.0-r19
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE '(phosh|libphosh)(-lang|-schemas|-portalsconf|-dbg)?'); do
	pkgs="$pkgs $p=$V"
done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|Downgrading|OK:|ERROR' | tail -4
sudo rc-service greetd restart >/dev/null 2>&1
sleep 25
pgrep -x phrog >/dev/null && echo "phrog up" || echo "phrog NOT running"
real=$(cat $STATE)
echo 2 | sudo tee $INJ >/dev/null
sleep 8
sudo env $G grim -o DSI-2 -s 0.35 /tmp/r19-DSI-2.png
sudo env $G grim -o DSI-1 -s 0.25 /tmp/r19-DSI-1.png
echo "lockshields created: $(sudo grep -c '"phosh lockshield")' /tmp/phrog-wl.log)"
# close and open once more: the second hotplug must behave the same
echo 1 | sudo tee $INJ >/dev/null
sleep 6
echo 2 | sudo tee $INJ >/dev/null
sleep 8
sudo env $G grim -o DSI-2 -s 0.35 /tmp/r19-DSI-2b.png
echo "lockshields created after 2nd open: $(sudo grep -c '"phosh lockshield")' /tmp/phrog-wl.log)"
sudo grep -vE '^\[' /tmp/phrog-wl.log | grep -iE 'critical|segfault' | tail -5 | cut -c1-200
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
pgrep -x phrog >/dev/null && echo "phrog alive" || echo "phrog DEAD"
sudo chmod 644 /tmp/r19-*.png
