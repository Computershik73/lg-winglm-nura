#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
for c in $($E gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.GetClients | grep -o "/org/gnome/SessionManager/Client[0-9]*"); do
	a=$($E gdbus call --session --dest org.gnome.SessionManager --object-path $c --method org.gnome.SessionManager.Client.GetAppId 2>&1)
	s=$($E gdbus call --session --dest org.gnome.SessionManager --object-path $c --method org.gnome.SessionManager.Client.GetStatus 2>&1)
	p=$($E gdbus call --session --dest org.gnome.SessionManager --object-path $c --method org.gnome.SessionManager.Client.GetUnixProcessId 2>&1)
	echo "$c $a status=$s pid=$p"
done
