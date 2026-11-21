#!/bin/sh
# Test session with phosh under gdb; switch DSI-1 off DELAY seconds after phosh appears, as during boot
DELAY=$1
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
sudo rm -f /run/greetd.run; sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 80); do pgrep -u user -x phosh >/dev/null && break; sleep 0.25; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
PP=$(pgrep -u user -x phosh)
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep $DELAY
$E wlr-randr --output DSI-1 --off
sleep 4
$E wlr-randr --output DSI-1 --on --transform 90 2>/dev/null
sleep 4
echo "delay $DELAY: phosh $([ "$(pgrep -u user -x phosh)" = "$PP" ] && echo alive || echo GONE), autologin lines $(grep -c '^\[initial_session\]' $C)"
grep -E "[wayland]|Gdk-Message|killed by signal|exited with code" /tmp/sess.log | tail -4 | cut -c1-200
