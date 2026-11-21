#!/bin/sh
# Start stevia while the swivel is closed (DSI-2 off), then open it; stevia must survive and show on DSI-2
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
echo 1 | sudo tee $INJ >/dev/null; sleep 4
$E wlr-randr | grep -E '^DSI|Enabled' | tr '\n' ' '; echo
sh /tmp/stevia-debug.sh | grep -E "running|DIED"
sleep 2
echo 2 | sudo tee $INJ >/dev/null; sleep 5
echo "after open: stevia $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia')"
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true >/dev/null; sleep 2
$E grim -o DSI-2 -s 0.5 /tmp/sc-2.png; chmod 644 /tmp/sc-2.png
$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null
echo "end: stevia $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia')"
grep -E "CRITICAL|Segm|ERROR|surface" /tmp/stevia.log | grep -v dconf | tail -8 | cut -c1-180
