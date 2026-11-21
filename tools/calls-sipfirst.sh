#!/bin/sh
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E gsettings set org.gnome.Calls autoload-plugins "['sip', 'mm']"
$E gsettings get org.gnome.Calls autoload-plugins
if pgrep -u user -x gnome-calls >/dev/null; then
	# only restart when no call is going on (MM side)
	if mmcli -m any --voice-list-calls 2>/dev/null | grep -q "/Call/"; then
		echo "a call is active, not restarting Calls"
		exit 0
	fi
	pkill -u user -x gnome-calls
	sleep 1
fi
$E gdbus call --session --dest org.gnome.Calls --object-path /org/gnome/Calls \
	--method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
sleep 8
echo "calls: $(pgrep -u user -x gnome-calls)"
cat /run/winglm-volte/status
sudo tail -3 /var/log/winglm-volte.trace
