#!/bin/sh
for f in /sys/class/smartcover/swivel/* /sys/devices/virtual/power/dd/swivel_state /sys/devices/platform/soc/soc:gpio_keys/swivel_event_refresh; do
  [ -f "$f" ] && echo "$f = $(cat "$f" 2>&1 | head -c 200)"
done
ls -la /sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
echo "== Touch Sub log"
sudo dmesg | grep -E '\[Touch Sub\]|swivel|SWIVEL' | grep -vE 'parse|fw_image|gpio_init|direction' | tail -40
