#!/bin/sh
set -e
cd /tmp
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r7.apk /tmp/device-lg-winglm-brightness-1-r7.apk 2>&1 | grep -E 'Installing|Upgrading|OK:|ERROR' | tail -5
gsettings list-keys org.postmarketos.winglm.brightness 2>&1 | head -3
# start the service in the running phosh session
PH=$(pgrep -u user -x phosh | head -1)
tr '\0' '\n' < /proc/$PH/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|HOME|USER|PATH|LANG)=' > /tmp/phosh-user.env
pkill -u user -f 'winglm-brightness --daemon' 2>/dev/null || true
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') setsid winglm-brightness --daemon > /tmp/winglm-brightness.log 2>&1 < /dev/null &
sleep 3
pgrep -u user -fa 'winglm-brightness --daemon' | head -2
for b in panel0-backlight panel1-backlight; do echo "$b $(cat /sys/class/backlight/$b/brightness)"; done
cat /tmp/winglm-brightness.log
