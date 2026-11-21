#!/bin/sh
# never read /sys/power/wakeup_count here: it blocks while wakeup events are in progress
cat /sys/power/state; cat /sys/power/mem_sleep 2>/dev/null; echo "autosleep: $(cat /sys/power/autosleep 2>/dev/null)"
echo "wake_lock: $(cat /sys/power/wake_lock 2>/dev/null | head -c 300)"
ls /sys/class/rtc/; cat /sys/class/rtc/rtc0/name; echo "rtc wakeup: $(cat /sys/class/rtc/rtc0/device/power/wakeup 2>/dev/null)"
sudo mount | grep -q debugfs || sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null
echo "--- active wakeup sources"
sudo timeout 5 awk 'NR==1 || $6 > 0' /sys/kernel/debug/wakeup_sources 2>/dev/null | head -30
echo "--- most events"
sudo timeout 5 sort -k3 -n -r /sys/kernel/debug/wakeup_sources 2>/dev/null | head -12
echo ---
sudo timeout 5 cat /sys/kernel/debug/suspend_stats 2>/dev/null | head -20
dmesg | grep -iE "PM: |Freezing|resource busy" | tail -10
