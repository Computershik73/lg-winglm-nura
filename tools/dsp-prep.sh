#!/bin/sh
# Prepare DSP bring-up: SSR restart levels, pd-mapper, look at qrtr
R=/home/user/.local/share/abuild/aports
sudo apk add --no-network --repository "$R" pd-mapper pd-mapper-openrc 2>&1 | grep -E 'Installing|ERROR|OK:' | tail -3
for s in /sys/bus/msm_subsys/devices/*; do
	n=$(cat $s/name 2>/dev/null); l=$(cat $s/restart_level 2>/dev/null)
	echo "$n: state=$(cat $s/state) restart_level=$l"
	case "$n" in adsp|modem|cdsp|ipa_fws)
		[ "$l" = "SYSTEM" ] && echo RELATED | sudo tee $s/restart_level >/dev/null && echo "  -> RELATED";;
	esac
done
ls /run/msm-firmware-loader/target/*.jsn
sudo rc-service pd-mapper start 2>&1 | tail -2
sleep 2
pgrep -a pd-mapper
qrtr-lookup 2>&1 | head -30
