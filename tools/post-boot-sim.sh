#!/bin/sh
C=/etc/phrog/greetd-config.toml; B=/var/lib/winglm-greetd-config.toml.before-autologin
for i in $(seq 1 60); do pgrep -u user -x phosh >/dev/null && break; sleep 2; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
uptime
ls -la /run/msm-firmware-loader/target/modem_pr
sudo cat /var/log/winglm-vss.log | tail -3
rc-status | grep -E "winglm|modemmanager|q6voiced|bluetooth"
for i in $(seq 1 40); do
	M=$(mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | head -1 | cut -d/ -f2)
	if [ -n "$M" ]; then
		st=$(mmcli -m $M -K 2>/dev/null | grep "modem.generic.state " | sed "s/.*: //")
		case "$st" in registered|connected|failed) break;; esac
	fi
	sleep 5
done
uptime
mmcli -m $M -K 2>/dev/null | grep -E "generic.state |state-failed-reason|access-technologies.value|signal-quality.value|operator-name|registration-state :"
echo "phosh: $(pgrep -u user -x phosh) calls: $(pgrep -u user -x gnome-calls) callaudiod: $(pgrep -x callaudiod) q6voiced: $(pgrep -x q6voiced)"
