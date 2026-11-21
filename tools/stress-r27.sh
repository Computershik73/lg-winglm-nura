#!/bin/sh
R=/home/user/.local/share/abuild/aports
args=""; for p in $(apk info 2>/dev/null | grep -E '^(phosh|libphosh)' | sort -u); do [ -f $R/aarch64/$p-0.58.0-r27.apk ] && args="$args $p=0.58.0-r27"; done
sudo apk add --no-network --repository $R $args 2>&1 | tail -1
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
OLD=$(pgrep -n -u user -x phosh); sudo rm -f /run/greetd.run; sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 60); do N=$(pgrep -n -u user -x phosh); [ -n "$N" ] && [ "$N" != "$OLD" ] && break; sleep 0.5; done; sleep 0.5
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
PP=$(pgrep -n -u user -x phosh); echo "phosh $PP $(apk info -v 2>/dev/null | grep '^phosh-0')"
sudo cat /proc/$PP/environ | tr "\0" "\n" | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
alive() { [ "$(pgrep -u user -x phosh)" = "$PP" ] && echo "  ok" || { echo "  PHOSH GONE"; grep -iE "\[wayland\]|crit|gdk-message|signal" /tmp/sess.log | grep -vE "GL_|RTKit|dma-buf|Calls|gsd-" | tail -6 | cut -c1-200; exit 1; }; }
psm() { $E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<$1>" >/dev/null; }
sleep 3
for i in 1 2 3; do sudo loginctl lock-session $SES; sleep 2; psm 1; sleep 3; psm 0; sleep 3; echo "locked blank cycle $i"; alive; done
psm 1; sleep 2; echo 1 | sudo tee $INJ >/dev/null; sleep 3; echo 2 | sudo tee $INJ >/dev/null; sleep 3; psm 0; sleep 4; echo "swivel while blanked"; alive
sudo loginctl unlock-session $SES; sleep 2
for i in 1 2; do psm 1; sleep 3; psm 0; sleep 3; echo "unlocked blank cycle $i"; alive; done
for i in 1 2; do echo 1 | sudo tee $INJ >/dev/null; sleep 3; echo 2 | sudo tee $INJ >/dev/null; sleep 4; echo "swivel cycle $i"; alive; done
grep -cE "CRITICAL" /tmp/sess.log
