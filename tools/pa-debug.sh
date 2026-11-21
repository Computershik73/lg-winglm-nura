#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E pulseaudio -k 2>/dev/null; sleep 2
$E pulseaudio --start --log-level=4 --log-target=file:/tmp/pa.log 2>&1 | tail -2; sleep 6
grep -iE "voice|verb|ucm" /tmp/pa.log | grep -viE "HiFi.*(Speaker|Earpiece|Headphones|Mic)\b.*priority" | head -40 | cut -c1-200
