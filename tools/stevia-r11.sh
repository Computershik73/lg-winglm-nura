#!/bin/sh
# Install stevia r11, run it in the session like gnome-session does, check it survives and the OSK shows on DSI-2
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE 'stevia(-lang|-schemas|-dbg|-doc|-systemd)?'); do pkgs="$pkgs $p=0.58.0-r13"; done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|ERROR|OK:' | tail -4
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
for p in $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia'); do kill $p; done
$E setsid /usr/bin/phosh-osk-stevia --allow-replacement > /tmp/stevia.log 2>&1 < /dev/null &
sleep 6
pgrep -u user -f '^/usr/bin/phosh-osk-stevia' >/dev/null && echo "stevia running" || { echo "stevia DIED"; tail -5 /tmp/stevia.log; }
grep -iE 'critical|weak ref|unavailable' /tmp/stevia.log | head -5
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true >/dev/null
sleep 2
$E grim -o DSI-2 -s 0.35 /tmp/s11-DSI-2.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null
# swivel round trip: keyboard moves to the main screen and back
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
real=$(cat /sys/class/smartcover/swivel/state)
echo 1 | sudo tee $INJ >/dev/null; sleep 4
echo "closed: output setting $($E gsettings get mobi.phosh.osk output)"
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true >/dev/null; sleep 2
$E grim -o DSI-1 -s 0.2 /tmp/s11-closed-DSI-1.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null
echo 2 | sudo tee $INJ >/dev/null; sleep 5
echo "$real" | sudo tee $INJ >/dev/null; sleep 2
pgrep -u user -f '^/usr/bin/phosh-osk-stevia' >/dev/null && echo "stevia still running" || echo "stevia DIED after swivel"
chmod 644 /tmp/s11-*.png
