#!/bin/sh
set -e
R=/home/user/.local/share/abuild/aports
echo "== phoc r11"
pkgs=$(apk info 2>/dev/null | grep -xE 'phoc(-lang|-schemas)?' | tr '\n' ' ')
sudo apk add --no-network --repository "$R" -u $pkgs 2>&1 | grep -E 'Upgrading|OK:|ERROR' | tail -4
echo "== device r8 + phosh helpers"
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r8.apk /tmp/device-lg-winglm-phosh-1-r8.apk 2>&1 | grep -E 'Installing|Upgrading|OK:|ERROR' | tail -4
apk info -e device-lg-winglm-brightness >/dev/null 2>&1 && sudo apk del device-lg-winglm-brightness 2>&1 | grep -E 'Purging|OK:' | tail -2
ls /etc/xdg/autostart/ | grep winglm
apk info -v 2>/dev/null | grep -E '^(phoc|device-lg-winglm)'
echo "== stage boot image"
sha256sum /tmp/boot-r5.img
