#!/bin/sh
# point GNOME Calls at the local VoLTE gateway and restart it inside the
# graphical session (D-Bus activation, so polkit sees the active session)
mkdir -p ~/.config/calls
cat > ~/.config/calls/sip-account.cfg <<CFG
[sip-01]
Id=volte@127.0.0.1
Host=127.0.0.1
User=volte
DisplayName=VoLTE
Protocol=UDP
Port=5070
AutoConnect=true
DirectMode=false
LocalPort=0
CanTel=true
CFG
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG|XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
# password (the local gateway ignores it) in the in-memory session keyring
for proto in sip udp UDP; do
	printf 'volte' | $E secret-tool store --collection=session --label='Calls Password for volte@127.0.0.1' \
		xdg:schema sm.puri.Calls server 127.0.0.1 username volte protocol $proto 2>&1 | head -2
done
$E secret-tool search --all xdg:schema sm.puri.Calls 2>/dev/null | grep -E "^attribute" | sort -u | head -8
pkill -x gnome-calls
sleep 1
$E gdbus call --session --dest org.gnome.Calls --object-path /org/gnome/Calls \
	--method org.freedesktop.DBus.Peer.Ping > /dev/null 2>&1
sleep 4
P=$(pgrep -n -u user -x gnome-calls)
echo "calls: $P parent: $(ps -o pid,args | awk -v p=$(awk '/PPid/{print $2}' /proc/$P/status) '$1==p' | cut -c1-60)"
