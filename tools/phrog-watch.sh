#!/bin/sh
sudo rm -f /tmp/phrog-session.log
sudo rc-service greetd restart >/dev/null 2>&1
start=$(date +%s)
last=""
for i in $(seq 1 60); do
	p=$(pgrep -f '^/usr/sbin/phrog' | head -1)
	s=$(cat /sys/class/smartcover/swivel/state)
	now="phrog=${p:-none} swivel=$s"
	if [ "$now" != "$last" ]; then
		echo "t=$(( $(date +%s) - start ))s $now"
		last=$now
	fi
	sleep 1
done
echo "== log tail"
grep -vE 'faccessat|swcatalog|metainfo|Glycin|background image|handle position|polkit|Gvc-CRITICAL|dbus-daemon|^$|systemd' /tmp/phrog-session.log | tail -15 | cut -c1-200
