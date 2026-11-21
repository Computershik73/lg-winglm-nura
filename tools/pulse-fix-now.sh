#!/bin/sh
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG|XDG_CONFIG_HOME|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|XDG_DATA_DIRS)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
grep DBUS /tmp/phosh-user.env
$E sh /tmp/winglm-pulse-session
sleep 3
echo "pulseaudio: $(pgrep -a -u user -x pulseaudio)"
$E pactl list short sinks | cut -c1-110
echo "default: $($E pactl get-default-sink)"
sudo logread 2>/dev/null | grep -a winglm-pulse-session | tail -2
