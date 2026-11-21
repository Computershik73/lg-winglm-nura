#!/bin/sh
echo "== input devices"
grep -E '^(N|S|H):' /proc/bus/input/devices | paste - - - | sed 's/\t/ | /g'
echo "== swivel / hall in dmesg"
sudo dmesg | grep -iE 'swivel|hall|touch_notify|touch sub|\[Touch' | grep -viE 'parse' | head -40
echo "== sysfs nodes"
find /sys -maxdepth 6 -iname '*swivel*' 2>/dev/null | head -20
echo "== irqs touch"
grep -iE 'touch|hall|swivel|ts_|ftm|sw42|tsp' /proc/interrupts | head -10
