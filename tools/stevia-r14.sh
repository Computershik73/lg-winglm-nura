#!/bin/sh
# Install stevia r14, start it inside the graphical session's cgroup, test it across swivel changes
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE 'stevia(-lang|-schemas|-dbg|-doc|-systemd)?'); do pkgs="$pkgs $p=0.58.0-r15"; done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|ERROR|OK:' | tail -4
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
PP=$(pgrep -u user -x phosh | head -1)
CG=$(sed -n 's/^0:://p' /proc/$PP/cgroup)
for p in $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia'); do kill $p; done
sleep 1
$E G_MESSAGES_DEBUG=phosh-osk-stevia setsid sh -c 'echo $$ > /tmp/stevia-wrap.pid; sleep 1; exec /usr/bin/phosh-osk-stevia --allow-replacement' > /tmp/stevia.log 2>&1 < /dev/null &
sleep 0.3
echo "$(cat /tmp/stevia-wrap.pid)" | sudo tee /sys/fs/cgroup$CG/cgroup.procs >/dev/null
sleep 6
alive() { pgrep -u user -f '^/usr/bin/phosh-osk-stevia' >/dev/null && echo "stevia running" || { echo "stevia DIED"; tail -4 /tmp/stevia.log; }; }
osk() { $E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible $1 >/dev/null; }
alive
grep -E 'unavailable|Creating input surface on|Moving input|Waiting|postpon' /tmp/stevia.log | cut -c1-140
osk true; sleep 2; $E grim -o DSI-2 -s 0.35 /tmp/s14-open-DSI-2.png; osk false
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
real=$(cat /sys/class/smartcover/swivel/state)
echo 1 | sudo tee $INJ >/dev/null; sleep 5
alive
osk true; sleep 2; $E grim -o DSI-1 -s 0.2 /tmp/s14-closed-DSI-1.png; osk false
echo 2 | sudo tee $INJ >/dev/null; sleep 6
alive
osk true; sleep 2; $E grim -o DSI-2 -s 0.35 /tmp/s14-reopen-DSI-2.png; osk false
echo "$real" | sudo tee $INJ >/dev/null; sleep 2
grep -cE 'unavailable' /tmp/stevia.log
grep -E 'Creating input surface on|Moving input|Waiting' /tmp/stevia.log | cut -c1-140 | tail -8
chmod 644 /tmp/s14-*.png
