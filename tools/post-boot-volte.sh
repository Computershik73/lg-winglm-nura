#!/bin/sh
C=/etc/phrog/greetd-config.toml; B=/var/lib/winglm-greetd-config.toml.before-autologin
for i in $(seq 1 60); do pgrep -u user -x phosh >/dev/null && break; sleep 2; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
sudo rm -f /usr/local/bin/winglm-logged-session
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
# wait for IMS registration (modem registration + Calls + IMS)
for i in $(seq 1 60); do grep -qs '^ims=registered' /run/winglm-volte/status && break; sleep 3; done
uptime
rc-status | grep -E "winglm|modemmanager|q6voiced"
sudo grep -v Deprecat /var/log/winglm-volte.log | tail -14
cat /run/winglm-volte/status
ip route | grep default
mmcli -m any -K 2>/dev/null | grep -E "generic.state |access-technologies.value|signal-quality.value"
echo "phosh: $(pgrep -u user -x phosh) calls: $(pgrep -u user -x gnome-calls)"
