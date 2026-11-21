#!/bin/sh
echo "== uptime"; cat /proc/uptime
echo "== procs"; ps -o pid,args | grep -E 'sway|vkcube|es2gears|winglm-panel' | grep -v grep
echo "== connectors"
for c in /sys/class/drm/card0-*; do echo "$c: $(cat $c/status 2>/dev/null) $(cat $c/enabled 2>/dev/null) dpms=$(cat $c/dpms 2>/dev/null)"; done
echo "== dri state (crtc/plane summary)"
sudo sed -n '/^crtc\[/,/^connector/p' /sys/kernel/debug/dri/0/state 2>/dev/null | grep -E 'crtc\[|enable=|active=|mode:' | head -20
sudo grep -A4 '^connector\[' /sys/kernel/debug/dri/0/state | head -20
echo "== dmesg errors (last 40)"
sudo dmesg | grep -iE 'sde error|panel_dead|wait_for_idle|esd|dsi' | tail -40
echo "== recovery log"; tail -n 15 /var/log/winglm-panel-recovery.log 2>/dev/null
echo "== wlr-randr"
for d in /tmp/xdg-* /run/user/*; do for s in "$d"/wayland-[0-9]*; do [ -S "$s" ] && XDG_RUNTIME_DIR=$d WAYLAND_DISPLAY=${s##*/} wlr-randr; done; done 2>&1 | head -40
