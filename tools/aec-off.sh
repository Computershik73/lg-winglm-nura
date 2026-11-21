#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
$E pactl unload-module module-filter-apply
$E pactl unload-module module-filter-heuristics
$E pactl list short modules | grep -ciE "filter|echo"
# mic volume of both profiles to 100 %
$CA 1 >/dev/null; sleep 1.5
$E pactl set-source-volume @DEFAULT_SOURCE@ 100%
echo "voice call mic: $($E pactl get-source-volume @DEFAULT_SOURCE@ | head -1)"
$CA 0 >/dev/null; sleep 1.5
$E pactl set-source-volume @DEFAULT_SOURCE@ 100%
echo "hifi mic: $($E pactl get-source-volume @DEFAULT_SOURCE@ | head -1)"
