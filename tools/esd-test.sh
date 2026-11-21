#!/bin/sh
# Simulate an ESD failure on the swivel panel, then try to recover it the way
# Android's HWC would: output off + on through the compositor.
export XDG_RUNTIME_DIR=/tmp/xdg-user
export WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | head -1)
T=/sys/kernel/debug/qcom,mdss_dsi_rm692c9_pv_half_fhd_cmd/esd_trigger
cnt() { sudo dmesg | grep -cE "$1"; }

sudo dmesg -C
echo "[$(date +%T)] trigger ESD on DSI-2"
echo 1 | sudo tee "$T" >/dev/null
sleep 6
echo "  PANEL_DEAD reports: $(cnt 'report PANEL_DEAD') pending: $(cnt 'ESD recovery already pending') wait_for_idle: $(cnt wait_for_idle)"
sudo dmesg | grep -E 'PANEL_DEAD' | head -2 | cut -c1-150

echo "[$(date +%T)] recover: wlr-randr off/on"
wlr-randr --output DSI-2 --off; echo "  off rc=$?"
sleep 1
wlr-randr --output DSI-2 --on; echo "  on rc=$?"
sleep 5
sudo dmesg -C; sleep 5
echo "[$(date +%T)] after recovery, 5s window: pending=$(cnt 'ESD recovery already pending') wait_for_idle=$(cnt wait_for_idle) dpms=$(cat /sys/class/drm/card0-DSI-2/dpms)"
wlr-randr | grep -A3 '^DSI-2' | head -4
