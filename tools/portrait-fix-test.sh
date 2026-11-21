#!/bin/sh
# Closed + locked -> open while locked -> unlock: the main screen must stay landscape
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
real=$(cat /sys/class/smartcover/swivel/state)
tf() { $E wlr-randr | awk '/^DSI-1/{f=1} f&&/Transform/{print $2; exit}'; }
psm() { $E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<$1>" >/dev/null; }
for round in 1 2; do
	echo 1 | sudo tee $INJ >/dev/null; sleep 4
	echo "round $round closed: $(tf)"
	sudo loginctl lock-session "$SES"; sleep 3
	echo "  locked: $(tf)"
	if [ $round = 2 ]; then psm 1; sleep 2; fi
	echo 2 | sudo tee $INJ >/dev/null; sleep 3
	if [ $round = 2 ]; then psm 0; sleep 3; fi
	echo "  opened while locked: $(tf)"
	sudo loginctl unlock-session "$SES"; sleep 4
	echo "  unlocked: $(tf)"
	$E grim -o DSI-1 -s 0.2 /tmp/pf-$round.png
done
echo "$real" | sudo tee $INJ >/dev/null; sleep 3
echo "final: $(tf)"
chmod 644 /tmp/pf-*.png
