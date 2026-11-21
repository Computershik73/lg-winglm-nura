#!/bin/sh
# install the ModemManager fork; first connection only by hand
R=$HOME/.local/share/abuild/aports/aarch64
V=1.25.95_git20261005-r${MMREL:-2}
sudo nmcli connection modify RUS connection.autoconnect no
pk=""
for p in modemmanager modemmanager-openrc modemmanager-udev modemmanager-lang modemmanager-dev libmm-glib; do
	apk info -e $p >/dev/null 2>&1 && pk="$pk $R/$p-$V.apk"
done
sudo apk add --no-network --allow-untrusted $pk 2>&1 | tail -1
apk info -v 2>/dev/null | grep -E "^modemmanager-1|^libmm-glib"
sudo rc-service modemmanager zap >/dev/null 2>&1
sudo pkill -x ModemManager; sleep 2
sudo rc-service modemmanager start 2>&1 | tail -1
for i in $(seq 1 30); do mmcli -m any 2>/dev/null | grep -q "state: registered\|state: connected" && break; sleep 2; done
sudo mmcli --set-logging=DEBUG >/dev/null 2>&1
mmcli -m any | grep -E "  state|ports|drivers" | sed -E 's/[0-9]{12,}/<n>/g'
