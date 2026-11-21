#!/bin/sh
# Calls r3 + daemon with the CS fallback (test deploy), then watch Calls'
# registrations while IMS comes up after a daemon restart
R=$HOME/.local/share/abuild/aports/aarch64
cd $R && sudo apk add --allow-untrusted ./calls-51.1-r3.apk ./calls-lang-51.1-r3.apk 2>&1 | tail -1
sudo cp /tmp/volte/volted.py /usr/lib/winglm-volte/
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -u user -x gnome-calls
sudo rc-service winglm-volte restart 2>&1 | tail -1
sleep 2
$E gdbus call --session --dest org.gnome.Calls --object-path /org/gnome/Calls \
	--method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 150 ]; do
	grep -q "calls=1" /run/winglm-volte/status && grep -q "ims=registered" /run/winglm-volte/status && \
		sudo tail -n 30 /var/log/winglm-volte.trace | grep -q "GNOME Calls REGISTER" && \
		sudo tail -n 1 /var/log/winglm-volte.trace | grep -qv 503 && break
	sleep 5
done
sudo grep -aE "GNOME Calls REGISTER|IMS registered|VoLTE not|modem not ready|IMS PDN up" /var/log/winglm-volte.trace | tail -12 | cut -c1-120
cat /run/winglm-volte/status
