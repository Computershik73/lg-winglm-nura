#!/bin/sh
set -e
R=/home/user/.local/share/abuild/aports
pkgs=$(apk info 2>/dev/null | grep -E '^(phosh|libphosh)' | sort -u | tr '\n' ' ')
echo "installed: $pkgs"
sudo apk add --no-network --repository "$R" -u $pkgs 2>&1 | grep -vE '^\s*$' | tail -6
apk info -v 2>/dev/null | grep -E '^(phosh|libphosh)-[0-9]'
echo "== restart greeter"
sudo rc-service greetd restart >/dev/null 2>&1
sleep 20
ps -o pid,args | grep -E '[/]usr/sbin/phrog|[p]hoc -S' | cut -c1-90
sudo dmesg | tail -n 300 | grep -E 'sde error|PANEL_DEAD|wait_for_idle' | grep -v enc53 | tail -4
