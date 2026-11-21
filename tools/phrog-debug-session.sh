#!/bin/sh
# Debug copy of /usr/libexec/phrog-greetd-session: logs to /tmp, protocol
# trace on the compositor side, phoc debug messages.
PHOC_INI=/etc/phrog/phoc.ini
export XDG_CURRENT_DESKTOP=Phrog:Phosh:GNOME
export GNOME_SESSION_AUTOSTART_DIR=/usr/share/phrog/autostart:/etc/phrog/autostart
exec > /tmp/phrog-session.log 2>&1
dbus_command=""
[ -z "$DBUS_SESSION_BUS_ADDRESS" ] && dbus_command=dbus-run-session
exec env WAYLAND_DEBUG=server G_MESSAGES_DEBUG=all \
	$dbus_command phoc -S -C "${PHOC_INI}" -E 'env -u WAYLAND_DEBUG -u G_MESSAGES_DEBUG gnome-session --session=phrog'
