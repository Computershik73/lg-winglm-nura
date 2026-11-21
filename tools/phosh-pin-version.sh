#!/bin/sh
# usage: sh -s <pkgrel>   install the local phosh/libphosh build with that pkgrel
set -e
V=0.58.0-r$1
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE '(phosh|libphosh)(-lang|-schemas|-portalsconf|-dbg)?'); do
	pkgs="$pkgs $p=$V"
done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|Downgrading|OK:|ERROR' | tail -6
apk info -v 2>/dev/null | grep -E '^(phosh|libphosh)-[0-9]'
sudo rc-service greetd restart >/dev/null 2>&1
sleep 15
pgrep -f '^/usr/sbin/phrog' >/dev/null && echo "phrog running" || echo "phrog NOT running"
