#!/bin/sh
# Leftover greeter processes (no greeter runs while the user session is up)
sudo pkill -u greetd 2>/dev/null; sleep 1
echo "greetd procs left: $(pgrep -u greetd | wc -l)"
for p in $(pgrep -u user -f 'gnome-session-inhibit --inhibit idle'); do kill $p; done
PP=$(pgrep -u user -x phosh | head -1)
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|XDG_SESSION_ID|XDG_SEAT|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_DATA_DIRS)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E setsid gnome-session-inhibit --inhibit idle --reason "winglm tests" sleep 14400 >/dev/null 2>&1 < /dev/null &
sleep 3
echo "swivel state $(cat /sys/class/smartcover/swivel/state)"
$E wlr-randr | grep -E '^DSI|Enabled|Position|Transform'
$E grim -o DSI-1 -s 0.25 /tmp/st-1-DSI-1.png; $E grim -o DSI-2 -s 0.35 /tmp/st-1-DSI-2.png
# overview with Super+A
$E wtype -M logo -k a -m logo; sleep 2
$E grim -o DSI-1 -s 0.25 /tmp/st-2-DSI-1.png; $E grim -o DSI-2 -s 0.35 /tmp/st-2-DSI-2.png
$E wtype -M logo -k a -m logo; sleep 2
$E grim -o DSI-2 -s 0.35 /tmp/st-3-DSI-2.png
chmod 644 /tmp/st-*.png
