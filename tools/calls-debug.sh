#!/bin/sh
# restart GNOME Calls with debug output (temporary, for one echo test)
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG|XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP|XDG_SESSION_ID)=' > /tmp/phosh-user.env
pkill -u user -x gnome-calls
sleep 1
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') G_MESSAGES_DEBUG=all GST_DEBUG=2,rtpbin:4,rtpjitterbuffer:4,udpsrc:4,pulsesink:4,pulsesrc:4 \
	setsid gnome-calls --gapplication-service > /tmp/calls-debug.log 2>&1 < /dev/null &
sleep 6
echo "calls: $(pgrep -u user -x gnome-calls)"
grep -ciE "sip" /tmp/calls-debug.log
