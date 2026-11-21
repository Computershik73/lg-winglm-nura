#!/bin/sh
# compositor view vs Phosh's DisplayConfig view, same moment
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
date +%T
$E timeout 5 wlr-randr | grep -E '^[A-Z]|Enabled'
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.gnome.Mutter.DisplayConfig.GetCurrentState | sed 's/.*@a(iiduba(ssss)a{sv}) /logical: /; s/.*\], \[(/logical: [(/' | cut -c1-300
for b in /sys/class/backlight/*; do echo "${b##*/} $(cat $b/brightness) bl_power=$(cat $b/bl_power)"; done
