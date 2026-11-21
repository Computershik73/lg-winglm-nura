#!/bin/sh
# Simulate ESD on the MAIN panel and recover every output with
# off -> wait -> on (retry) through the compositor.
export XDG_RUNTIME_DIR=/tmp/xdg-user
export WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | head -1)
T=/sys/kernel/debug/qcom,mdss_dsi_sw43103_mp_fhd_dsc_cmd/esd_trigger
cnt() { sudo dmesg | grep -cE "$1"; }
recover() {
	o=$1
	wlr-randr --output "$o" --off
	sleep 3
	for i in 1 2 3 4 5; do
		wlr-randr --output "$o" --on 2>/dev/null && { echo "  $o on after try $i"; return 0; }
		sleep 1
	done
	echo "  $o FAILED to come back"
}

sudo cat /sys/kernel/debug/qcom,mdss_dsi_sw43103_mp_fhd_dsc_cmd/esd_check_mode 2>/dev/null | head -2
sudo dmesg -C
echo "[$(date +%T)] trigger ESD on DSI-1 (main)"
echo 1 | sudo tee "$T" >/dev/null
sleep 6
echo "  PANEL_DEAD: $(cnt 'report PANEL_DEAD') pending: $(cnt 'already pending') wait_for_idle: $(cnt wait_for_idle)"
sudo dmesg | grep -E 'PANEL_DEAD|panel_dead|esd' | head -4 | cut -c1-160
echo "[$(date +%T)] recover"
recover DSI-1
recover DSI-2
sleep 3; sudo dmesg -C; sleep 5
echo "[$(date +%T)] 5s after recovery: pending=$(cnt 'already pending') wait_for_idle=$(cnt wait_for_idle) dsi1=$(cat /sys/class/drm/card0-DSI-1/dpms) dsi2=$(cat /sys/class/drm/card0-DSI-2/dpms)"
