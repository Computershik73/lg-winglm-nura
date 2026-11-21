#!/bin/sh
set -e
R=/home/user/.local/share/abuild/aports
pkgs=$(apk info 2>/dev/null | grep -xE 'phoc(-lang|-schemas|-dbg)?' | tr '\n' ' ')
echo "installed phoc packages: $pkgs"
sudo apk add --no-network --repository "$R" -u $pkgs 2>&1 | grep -E 'Upgrading|OK:|ERROR' | tail -5
which grim >/dev/null 2>&1 || sudo env http_proxy=http://127.0.0.1:8888 https_proxy=http://127.0.0.1:8888 apk add grim 2>&1 | tail -1
sudo rm -f /tmp/phrog-session.log
sudo rc-service greetd restart >/dev/null 2>&1
sleep 20
sudo grep -E "Mapping touch|Looking up output" /tmp/phrog-session.log | cut -c1-120
ps -o pid,args | grep -E '[/]usr/sbin/phrog' | cut -c1-60
for o in DSI-1 DSI-2; do
	sudo env XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0 grim -o $o -s 0.4 /tmp/shot-$o.png && echo "shot $o"
done
