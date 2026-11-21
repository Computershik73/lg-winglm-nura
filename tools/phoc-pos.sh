#!/bin/sh
for f in /etc/phosh/phoc.ini /etc/phrog/phoc.ini; do
	sudo tee "$f" >/dev/null <<'EOF'
[core]
xwayland=false

# DSI-1: SW43103 main panel, 1080x2460 -> 360x820 logical
[output:DSI-1]
scale = 3
x = 0
y = 0

# DSI-2: RM692C9 swivel panel, 1080x1240 -> 360x413 logical, right of DSI-1
[output:DSI-2]
scale = 3
x = 360
y = 0

[output:Virtual-1]
enable = false
EOF
done
sudo rc-service greetd restart >/dev/null 2>&1
sleep 15
sudo env XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0 wlr-randr 2>&1 | grep -E '^DSI|Position|Enabled'
echo "== processes"
ps -o pid,args | grep -E '[/]usr/sbin/phrog|[p]hoc -S' | cut -c1-90
sudo dmesg | tail -n 200 | grep -E 'sde error|PANEL_DEAD|wait_for_idle' | grep -v enc53 | tail -4
