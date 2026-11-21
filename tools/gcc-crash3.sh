#!/bin/sh
ls -la /var/log/messages* 2>/dev/null | head -3
sudo tail -c 3000000 /var/log/messages 2>/dev/null | grep -aiE 'Settings|control-center|cc-|signal 11|signal 6|SIGSEGV|SIGABRT|dumped|Activated service' \
	| grep -avE 'winglm-volte|settings-daemon\.plugins' | tail -40 | cut -c1-240
echo "== screen"
cat /sys/class/backlight/*/brightness 2>/dev/null | tr '\n' ' '; echo
cat /sys/class/backlight/*/bl_power 2>/dev/null | tr '\n' ' '; echo
