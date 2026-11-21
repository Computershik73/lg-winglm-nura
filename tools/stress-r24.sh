#!/bin/sh
# phosh r24 in a logged one-shot session: swivel cycles, blanking, bar swipes/taps, lock; phosh must survive
R=/home/user/.local/share/abuild/aports
args=""; for p in $(apk info 2>/dev/null | grep -E '^(phosh|libphosh)' | sort -u); do [ -f $R/aarch64/$p-0.58.0-r24.apk ] && args="$args $p=0.58.0-r24"; done
sudo apk add --no-network --repository $R $args 2>&1 | tail -1
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
sudo rm -f /run/greetd.run; sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 30); do pgrep -u user -x phosh >/dev/null && break; sleep 1; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
PP=$(pgrep -u user -x phosh)
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C), phosh: $PP"
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
alive() { [ "$(pgrep -u user -x phosh)" = "$PP" ] && echo "  ok" || { echo "  PHOSH GONE"; grep -iE "error|crit|gdk-message" /tmp/sess.log | grep -vE "GL_|RTKit|dma-buf|Calls" | tail -5; exit 1; }; }
psm() { $E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<$1>" >/dev/null; }
shot() { $E grim -o DSI-1 -s 0.5 /tmp/$1-1.png; $E grim -o DSI-2 -s 0.5 /tmp/$1-2.png; chmod 644 /tmp/$1-*.png; }
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
sleep 12; echo "started"; alive
for i in 1 2 3; do echo 1 | sudo tee $INJ >/dev/null; sleep 3; echo 2 | sudo tee $INJ >/dev/null; sleep 4; echo "swivel cycle $i"; alive; done
for i in 1 2; do psm 1; sleep 3; psm 0; sleep 4; echo "blank cycle $i"; alive; done
shot s0
sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1232 540 800 300 20; sleep 2; shot s1; echo "swipe up"; alive
sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1205 540 1239 200 10; sleep 2; shot s2; echo "swipe down"; alive
sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2; shot s3; echo "tap"; alive
echo 1 | sudo tee $INJ >/dev/null; sleep 3; echo 2 | sudo tee $INJ >/dev/null; sleep 4; echo "swivel while unfolded"; alive
sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2; shot s4; echo "tap (fold)"; alive
sudo loginctl lock-session $SES; sleep 3; echo 1 | sudo tee $INJ >/dev/null; sleep 3; echo 2 | sudo tee $INJ >/dev/null; sleep 4
sudo loginctl unlock-session $SES; sleep 3; echo "lock + swivel + unlock"; alive
echo "OSK: $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia')"
