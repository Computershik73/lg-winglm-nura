#!/bin/sh
# One-shot session; DSI-1 off DELAY s after phosh appears (as during boot), on again; phosh must survive
DELAY=$1
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
OLD=$(pgrep -n -u user -x phosh); sudo rm -f /run/greetd.run; sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 120); do N=$(pgrep -n -u user -x phosh); [ -n "$N" ] && [ "$N" != "$OLD" ] && break; sleep 0.25; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
sleep 0.3
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep $DELAY
$E wlr-randr --output DSI-1 --off || echo "  wlr-randr off failed"
sleep 4
$E wlr-randr --output DSI-1 --on --transform 90 || echo "  wlr-randr on failed"
sleep 5
NOW=$(pgrep -n -u user -x phosh)
echo "delay $DELAY: phosh $PP -> ${NOW:-none} $([ "$NOW" = "$PP" ] && echo SURVIVED || echo GONE), autologin lines $(grep -c '^\[initial_session\]' $C)"
[ "$NOW" = "$PP" ] || grep -E "\[wayland\]|Gdk-Message|killed by signal|exited with code|phosh.*CRITICAL" /tmp/sess.log | tail -5 | cut -c1-200
