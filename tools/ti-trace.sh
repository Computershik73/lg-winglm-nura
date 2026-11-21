#!/bin/sh
# Run Settings > Wi-Fi with WAYLAND_DEBUG, open "hidden network" dialog, click the entry, show text-input traffic
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -u user -x gnome-control-c; sleep 1
$E WAYLAND_DEBUG=client setsid gnome-control-center wifi > /tmp/gcc-wl.log 2>&1 < /dev/null &
sleep 7
$E wlrctl pointer move -5000 -5000; $E wlrctl pointer move 370 238; sleep 0.3; $E wlrctl pointer click left
sleep 2
echo "--- clicking entry"
N0=$(wc -l < /tmp/gcc-wl.log)
$E wlrctl pointer move -5000 -5000; $E wlrctl pointer move 464 214; sleep 0.3; $E wlrctl pointer click left
sleep 2
tail -n +$N0 /tmp/gcc-wl.log | grep -E "text_input|wl_pointer.button|keyboard.enter" | head -20
grep -c text_input /tmp/gcc-wl.log
grep -E "text_input_manager|zwp_text" /tmp/gcc-wl.log | head -5
grep -E "phosh-osk-stevia|active:" /tmp/stevia.log | tail -3
