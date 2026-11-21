#!/bin/sh
grep -n 'sway' /home/user/sway-gpu-demo.sh | head -5
sudo rc-service seatd start >/dev/null 2>&1 || sudo rc-service seatd restart
sleep 1
mark=$(cut -d' ' -f1 /proc/uptime)
setsid sh /home/user/sway-gpu-demo.sh > /tmp/sway-demo-launch.log 2>&1 < /dev/null &
sleep 15
echo "== processes"
ps -o pid,args | grep -E 'sway|vkcube|es2gears' | grep -v grep
echo "== kernel since $mark"
sudo dmesg | awk -v m="$mark" '{ s=$0; sub(/^\[ */, "", s); if (s+0 >= m) print }' | grep -E 'sde error|PANEL_DEAD|TE check|RM692C9|wait_for_idle' | grep -v enc53 | tail -15
echo "== outputs"
XDG_RUNTIME_DIR=/tmp/xdg-user WAYLAND_DISPLAY=$(ls /tmp/xdg-user | grep -E '^wayland-[0-9]+$' | head -1) wlr-randr 2>&1 | grep -E '^[A-Z]|Enabled|current'
tail -5 /tmp/sway-gpu.log
