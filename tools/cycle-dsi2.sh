#!/bin/sh
export XDG_RUNTIME_DIR=/tmp/xdg-user
for s in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do [ -S "$s" ] && export WAYLAND_DISPLAY=${s##*/}; done
echo "using $WAYLAND_DISPLAY"
sudo dmesg | grep -iE 'pending|panel_dead|wait_for_idle' | tail -5
mark=$(cut -d' ' -f1 /proc/uptime)
wlr-randr --output DSI-2 --off; echo "off rc=$?"
sleep 3
for i in 1 2 3 4 5 6; do
  wlr-randr --output DSI-2 --on && { echo "on (attempt $i)"; break; }
  sleep 1
done
sleep 4
echo "== kernel log since $mark"
sudo dmesg | awk -v m="$mark" '{t=$2; gsub(/[\[\]]/,"",$1); split($0,a,"]"); ts=substr(a[1],2)+0} ts>=m' | grep -iE 'sde error|dsi|panel' | tail -20
grep -A3 '^connector\[48\]' /dev/null 2>/dev/null
cat /sys/class/drm/card0-DSI-2/enabled
