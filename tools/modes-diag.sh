#!/bin/sh
echo "== wlr-randr (user session)"
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') wlr-randr 2>&1 | grep -vE '^    (4096|2560|19|18|17|16|15|14|13|12|10|8|6)[0-9]*x' | head -30
echo "== crtc modes (debugfs)"
sudo grep -E 'crtc\[|mode:' /sys/kernel/debug/dri/0/state | head -8
echo "== dsi set_mode / transfer time"
sudo dmesg | grep -E 'mdp_transfer_time_us|hactive=' | tail -6
echo "== panel DT timing props"
for n in $(sudo find /sys/firmware/devicetree/base -maxdepth 4 -type d \( -name 'qcom,mdss_dsi_sw43103*' -o -name 'qcom,mdss_dsi_rm692c9*' \) 2>/dev/null); do
	echo "-- $n"
	for t in $(sudo find $n -maxdepth 3 -type d -name 'timing@*' 2>/dev/null); do
		printf '%s: ' "$(basename $t)"
		for p in qcom,mdss-dsi-panel-framerate qcom,mdss-mdp-transfer-time-us qcom,mdss-dsi-panel-clockrate qcom,mdss-dsi-panel-width qcom,mdss-dsi-panel-height; do
			[ -f $t/$p ] && printf '%s=%d ' "${p#qcom,mdss-}" "0x$(sudo od -An -tx1 -N4 $t/$p | tr -d ' \n')"
		done
		echo
	done
done
