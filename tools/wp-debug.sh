#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -x wireplumber; sleep 1
$E WIREPLUMBER_DEBUG="spa.alsa:4,s-monitors:4,m-lua-scripting:2" setsid wireplumber > /tmp/wp.log 2>&1 < /dev/null &
sleep 12
$E wpctl status 2>&1 | sed -n '/Audio/,/Filters/p' | head -14
grep -iE "card|ucm|acp|error|fail|profile|lito|hw:0" /tmp/wp.log | grep -viE "bluez|v4l2|libcamera" | head -40 | cut -c1-220
