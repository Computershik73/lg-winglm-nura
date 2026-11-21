#!/bin/sh
# End-to-end: running service + injected PANEL_DEAD for DSI-2 (connector 48).
rc-service winglm-panel-recovery restart >/dev/null 2>&1
sleep 2
echo "<3>[drm:_sde_connector_report_panel_dead] [sde error]esd check failed report PANEL_DEAD conn_id: 48 enc_id: 47" > /dev/kmsg
sleep 12
tail -n 5 /var/log/winglm-panel-recovery.log
echo "dsi1=$(cat /sys/class/drm/card0-DSI-1/dpms) dsi2=$(cat /sys/class/drm/card0-DSI-2/dpms)"
