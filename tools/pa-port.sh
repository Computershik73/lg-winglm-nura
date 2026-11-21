#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E pulseaudio -k 2>/dev/null; sleep 2
$E pulseaudio --start --log-level=4 --log-target=file:/tmp/pa2.log 2>/dev/null; sleep 6
$E pactl set-card-profile 0 "Voice Call (Earpiece, Mic)"; sleep 2
S=$($E pactl list short sinks | awk '{print $2}' | head -1); echo "sink: $S"
$E pactl list sinks | sed -n '/Ports:/,/Active Port/p' | cut -c1-90
N0=$(wc -l < /tmp/pa2.log)
$E pactl set-sink-port "$S" "[Out] Speaker"; echo "set-sink-port exit $?"
sleep 1
tail -n +$N0 /tmp/pa2.log | grep -vE "^D: \[alsa-sink" | head -20 | cut -c1-180
$E pactl set-card-profile 0 "HiFi (Mic, Speaker)"
