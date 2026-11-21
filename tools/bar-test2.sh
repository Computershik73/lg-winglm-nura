#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
shot() { $E grim -o DSI-1 -s 0.5 /tmp/$1-1.png; $E grim -o DSI-2 -s 0.5 /tmp/$1-2.png; chmod 644 /tmp/$1-*.png; }
sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1232 540 800 300 20; sleep 2; shot c1
# tap the search entry (DSI-2 logical ~ (180, 13) -> raw (540, 40))
sudo python3 /tmp/ti.py tap /dev/input/event6 540 45; sleep 2; shot c2
echo "osk visible: $($E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible)"
sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2
echo "after fold osk: $($E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible)"
