#!/bin/sh
# run gnome-control-center inside the logged-in phosh session environment
PH=$(pgrep -u user -x phosh | head -1)
[ -n "$PH" ] || { echo "no phosh session"; exit 1; }
tr '\0' '\n' < /proc/$PH/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|XDG_SESSION_ID|HOME|USER|PATH|LANG|GDK_BACKEND)=' > /tmp/phosh-user.env
cat /tmp/phosh-user.env | cut -c1-80
echo "== run"
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') sh -c 'timeout 15 gnome-control-center > /tmp/gcc.log 2>&1; echo rc=$?'
grep -vE '^$' /tmp/gcc.log | tail -25 | cut -c1-200
apk info -v 2>/dev/null | grep -E '^gnome-control-center-[0-9]'
