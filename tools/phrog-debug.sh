#!/bin/sh
GS=$(pgrep -f 'gnome-session-binary --session=phrog' | head -1)
[ -n "$GS" ] || { echo "no gnome-session"; exit 1; }
sudo cat /proc/$GS/environ | tr '\0' '\n' | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_SESSION|HOME|USER|GSK|GDK|PATH)=' > /tmp/phrog.env
cat /tmp/phrog.env
echo "== run phrog 12s"
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') G_MESSAGES_DEBUG= timeout 12 /usr/sbin/phrog 2>&1 | grep -v '^$' | head -40
echo "rc=$?"
