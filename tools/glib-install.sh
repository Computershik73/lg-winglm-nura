#!/bin/sh
set -e
R=/home/user/.local/share/abuild/aports
pkgs=$(apk info 2>/dev/null | grep -xE 'glib(-dev|-lang|-dbg|-doc|-static|-bash-completion)?' | tr '\n' ' ')
echo "installed glib packages: $pkgs"
sudo apk add --no-network --repository "$R" -u $pkgs 2>&1 | grep -E 'Upgrading|OK:|ERROR' | tail -8
apk info -v 2>/dev/null | grep -E '^glib-2'
echo "== query_exists check (gio)"
gio info -a standard::type /var/lib/greetd 2>&1 | grep -E 'type|CRITICAL' | head -3
echo "== phrog alive test"
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') sh /tmp/phrog-alive.sh
grep -cE 'faccessat' /tmp/phrog-run2.log || true
