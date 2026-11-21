#!/bin/sh
# Same as portrait-repro.sh but with an app (foot) in front, then open the overview with Super+A
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
real=$(cat $STATE)
psm() { $E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<$1>" >/dev/null; }
shot() { $E timeout 5 grim -o DSI-1 -s 0.2 /tmp/pq-$1.png 2>/dev/null; echo "$1: $($E wlr-randr | awk '/^DSI-1/{f=1} f&&/Transform/{print $2; exit}')"; }
overview() { $E wtype -M logo -k a -m logo; sleep 2; }
sudo loginctl unlock-session "$SES"; sleep 1
echo 2 | sudo tee $INJ >/dev/null; sleep 3
pgrep -u user -x foot >/dev/null || { $E setsid foot >/dev/null 2>&1 < /dev/null & sleep 4; }
shot 0-foot
overview; shot 0-overview
overview; shot 0-overview-closed
# D: app in front, rotate while locked with screens on
sudo loginctl lock-session "$SES"; sleep 2
echo 1 | sudo tee $INJ >/dev/null; sleep 3
echo 2 | sudo tee $INJ >/dev/null; sleep 3
sudo loginctl unlock-session "$SES"; sleep 3
shot D-unlocked
overview; shot D-overview
overview
# E: app in front, rotations applied on wake
sudo loginctl lock-session "$SES"; sleep 2
psm 1; sleep 2; echo 1 | sudo tee $INJ >/dev/null; sleep 2; psm 0; sleep 3
psm 1; sleep 2; echo 2 | sudo tee $INJ >/dev/null; sleep 2; psm 0; sleep 3
sudo loginctl unlock-session "$SES"; sleep 3
shot E-unlocked
overview; shot E-overview
overview
# F: rotate while unlocked with the app in front, then overview
echo 1 | sudo tee $INJ >/dev/null; sleep 3
echo 2 | sudo tee $INJ >/dev/null; sleep 3
overview; shot F-overview
overview
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
chmod 644 /tmp/pq-*.png
