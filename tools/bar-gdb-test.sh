#!/bin/sh
# phosh under gdb; swipe/tap the home bar on DSI-2 (genuine touch), swivel close/open; screenshots
PP=$(pgrep -u user -x phosh | head -1)
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<0>" >/dev/null 2>&1
echo "locked: $($E gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive)"
sudo sh -c "gdb -p $PP -batch -ex 'set pagination off' -ex 'handle SIGPIPE SIGUSR1 SIGUSR2 nostop noprint' -ex continue -ex 'bt 25' > /tmp/phosh-gdb.log 2>&1 &"
sleep 4
shot() { $E grim -o DSI-1 -s 0.5 /tmp/$1-1.png; $E grim -o DSI-2 -s 0.5 /tmp/$1-2.png; chmod 644 /tmp/$1-*.png; }
shot g0
echo "swipe up on the DSI-2 bar"; sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1230 540 800 300 20; sleep 2; shot g1
echo "swipe down"; sudo python3 /tmp/ti.py swipe /dev/input/event6 540 1205 540 1239 200 10; sleep 2; shot g2
echo "tap"; sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2; shot g3
echo "swivel close/open while unfolded"; echo 1 | sudo tee $INJ >/dev/null; sleep 4; echo 2 | sudo tee $INJ >/dev/null; sleep 5; shot g4
echo "tap again (fold)"; sudo python3 /tmp/ti.py tap /dev/input/event6 540 1225; sleep 2; shot g5
echo "phosh alive: $(pgrep -u user -x phosh)"
sudo pkill -x gdb; sleep 1
grep -vE "^\[New Thread|^\[Thread|Reading symbols|^$|warning: (Unable|Could not)|Download|debuginfod" /tmp/phosh-gdb.log | tail -15 | cut -c1-200
