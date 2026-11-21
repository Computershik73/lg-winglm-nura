#!/bin/sh
# Run the recovery daemon in the foreground with tracing, inject a fake
# PANEL_DEAD for DSI-2 and show what it did.
rc-service winglm-panel-recovery stop >/dev/null 2>&1
( COOLDOWN=1 timeout 25 sh -x /usr/bin/winglm-panel-recovery > /tmp/rec-dbg.txt 2>&1 ) &
sleep 2
echo "<3>[drm:_sde_connector_report_panel_dead] [sde error]esd check failed report PANEL_DEAD conn_id: 48 enc_id: 47" > /dev/kmsg
wait
grep -vE '^\+ (case|\[|read|cut|uptime_s)|^\+\+ (cut)' /tmp/rec-dbg.txt | grep -vE 'charger|SMB1390|QG-K|aicl|usbin' | head -60
rc-service winglm-panel-recovery start >/dev/null 2>&1
