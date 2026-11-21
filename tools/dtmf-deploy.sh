#!/bin/sh
# Calls r4 (DTMF as SIP INFO) + daemon with DTMF to the modem media engine
if mmcli -m any --voice-list-calls 2>/dev/null | grep -q '/Call/'; then echo "a call is active, not deploying"; exit 1; fi
R=$HOME/.local/share/abuild/aports/aarch64
cd $R && sudo apk add --allow-untrusted ./calls-51.1-r4.apk ./calls-lang-51.1-r4.apk 2>&1 | tail -1
apk info -v 2>/dev/null | grep -E '^calls-51'
for f in mmpf.py modemmedia.py volted.py; do sudo cp /tmp/volte/$f /usr/lib/winglm-volte/; done
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -u user -x gnome-calls
sudo rc-service winglm-volte restart 2>&1 | tail -1
sleep 2
$E gdbus call --session --dest org.gnome.Calls --object-path /org/gnome/Calls \
	--method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 150 ]; do
	grep -q "ims=registered" /run/winglm-volte/status && grep -q "calls=1" /run/winglm-volte/status && break
	sleep 5
done
cat /run/winglm-volte/status
sudo grep -aE "GNOME Calls REGISTER|IMS registered|start failed" /var/log/winglm-volte.trace | tail -4 | cut -c1-110
