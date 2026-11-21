#!/bin/sh
# Reproduce "overview stays portrait after unlocking in the T position"
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
SES=$(loginctl list-sessions --no-legend | awk '$3=="user" && $4=="seat0" {print $1}' | head -1)
real=$(cat $STATE)
psm() { $E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<$1>" >/dev/null; }
shot() { $E timeout 5 grim -o DSI-1 -s 0.2 /tmp/pr-$1.png 2>/dev/null; echo "$1: $($E wlr-randr | awk '/^DSI-1/{f=1} f&&/Transform/{print $2; exit}')"; }
run() {
	N=$1; shift
	echo "== scenario $N"
	sudo loginctl unlock-session "$SES"; sleep 2
	echo 2 | sudo tee $INJ >/dev/null; sleep 3
	sudo loginctl lock-session "$SES"; sleep 2
	"$@"
	sudo loginctl unlock-session "$SES"; sleep 3
	shot "$N-unlocked"
}
# A: rotate to portrait and back while locked, screens on
sA() { echo 1 | sudo tee $INJ >/dev/null; sleep 3; echo 2 | sudo tee $INJ >/dev/null; sleep 3; shot A-locked; }
# B: blank, close, wake (portrait), blank, open, wake (landscape applied on wake)
sB() { psm 1; sleep 2; echo 1 | sudo tee $INJ >/dev/null; sleep 2; psm 0; sleep 3;
       psm 1; sleep 2; echo 2 | sudo tee $INJ >/dev/null; sleep 2; psm 0; sleep 3; shot B-locked; }
# C: like B but unlock right after waking (rotation may land after unlock)
sC() { psm 1; sleep 2; echo 1 | sudo tee $INJ >/dev/null; sleep 2; psm 0; sleep 3;
       psm 1; sleep 2; echo 2 | sudo tee $INJ >/dev/null; sleep 1; psm 0; }
run A sA
run B sB
run C sC
sleep 3; shot C-later
echo "$real" | sudo tee $INJ >/dev/null
sleep 3
chmod 644 /tmp/pr-*.png
