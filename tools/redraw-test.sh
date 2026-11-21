#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
real=$(cat $STATE)
echo 2 | sudo tee $INJ >/dev/null
sleep 3
sudo env $G grim -o DSI-2 -s 0.35 /tmp/rd-1-3s.png
sleep 12
sudo env $G grim -o DSI-2 -s 0.35 /tmp/rd-2-15s.png
# nudge: re-apply the same geometry, forces a new configure / frame
sudo env $G wlr-randr --output DSI-2 --pos 230,360 --scale 3
sleep 3
sudo env $G grim -o DSI-2 -s 0.35 /tmp/rd-3-nudge.png
tail -n 30 /tmp/phrog-session.log | grep -E "Keypad|configures|keypad:" | tail -6 | cut -c1-160
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
echo "state back to $(cat $STATE)"
