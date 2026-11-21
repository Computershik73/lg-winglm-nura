#!/bin/sh
# is the swivel exposed as a lid?
gdbus call --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower \
	--method org.freedesktop.DBus.Properties.GetAll org.freedesktop.UPower 2>&1 | tr ',' '\n' | grep -i lid
for d in /sys/class/input/input*; do
	sw=$(cat $d/capabilities/sw 2>/dev/null)
	[ -n "$sw" ] && [ "$sw" != 0 ] && echo "${d##*/} '$(cat $d/name)' sw=$sw ev=$(cat $d/capabilities/ev)"
done
grep -h -i lid /etc/elogind/logind.conf.d/* /etc/elogind/logind.conf 2>/dev/null | grep -v '^#'
apk info -v 2>/dev/null | grep -E '^upower'
