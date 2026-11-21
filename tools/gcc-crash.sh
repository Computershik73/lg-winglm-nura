#!/bin/sh
# swivel state, outputs, and recent gnome-control-center crashes
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG|XDG_CONFIG_HOME|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|XDG_DATA_DIRS)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
echo "== outputs (drm)"
for c in /sys/class/drm/card*-*; do printf '%s %s %s\n' "${c##*/}" "$(cat $c/status 2>/dev/null)" "$(cat $c/enabled 2>/dev/null)"; done
echo "== wlr-randr"
$E timeout 5 wlr-randr 2>&1 | grep -E '^[A-Za-z]|Enabled|current|Position' | head -20
echo "== versions"
apk info -v 2>/dev/null | grep -E '^gnome-control-center|^phosh-|^libadwaita|^gtk4|^phoc' | head
echo "== segfaults (dmesg)"
dmesg | grep -iE 'control-cent|segfault|traps:' | tail -6
echo "== run gnome-control-center (8 s)"
$E timeout 8 gnome-control-center > /tmp/gcc.out 2>&1; echo "exit=$?"
tail -25 /tmp/gcc.out | cut -c1-220
