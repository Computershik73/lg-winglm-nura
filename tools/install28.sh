#!/bin/sh
# stop the hand-started test daemon (pattern only in this stdin script)
for p in $(pgrep -f '^python3 -u volted.py'); do sudo kill $p; done
sleep 3
cd /tmp && sudo apk add --no-network --allow-untrusted ./device-lg-winglm-1-r28.apk ./device-lg-winglm-phosh-1-r28.apk \
	./device-lg-winglm-dsp-1-r28.apk ./device-lg-winglm-volte-1-r28.apk 2>&1 | tail -3
rc-update show default | grep -E "volte"
ls -la /etc/NetworkManager/dispatcher.d/50-winglm-routes /usr/lib/winglm-volte/ /etc/xdg/autostart/winglm-volte-calls.desktop | head -14
sudo rc-service winglm-volte start 2>&1 | tail -1
# run the session helper inside the logged in session
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|LANG|XDG_CONFIG_HOME)=' > /tmp/phosh-user.env
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') /usr/libexec/winglm-volte-calls
sleep 40
grep -v Deprecat /var/log/winglm-volte.log | tail -12
cat /run/winglm-volte/status
