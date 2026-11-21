#!/bin/sh
echo "== session"
ps -o pid,etime,args | grep -E '[/]usr/libexec/phosh$|[p]hoc -v|[w]inglm-brightness' | cut -c1-80
PH=$(pgrep -u user -x phosh | head -1)
[ -n "$PH" ] && tr '\0' '\n' < /proc/$PH/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|HOME|USER|PATH|LANG)=' > /tmp/phosh-user.env
echo "== gi gtk4"
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') python3 - <<'EOF'
import gi
gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw
print("gtk", Gtk.get_major_version(), Gtk.get_minor_version(), "adw ok")
EOF
echo "== gnome-control-center 12s"
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') sh -c 'timeout 12 gnome-control-center > /tmp/gcc.log 2>&1; echo rc=$?'
grep -vE '^$' /tmp/gcc.log | grep -vE 'faccessat' | tail -12 | cut -c1-180
echo "== brightness window 8s"
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') sh -c 'timeout 8 winglm-brightness > /tmp/wb.log 2>&1; echo rc=$?'
tail -5 /tmp/wb.log
