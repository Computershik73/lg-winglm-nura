#!/bin/sh
sudo dmesg > /tmp/dmesg-now.txt
grep -iE 'splash|cont_|dsi_display|sde error|sde_kms|panel_power|panel_enable|post_enable|panel_disable|power_off|dsi_panel_reset|msm_drm|\[drm\]|fbdev|fb0|pbsplash|plymouth|lge-dsi-panel:dsi|backlight:dsi' /tmp/dmesg-now.txt \
  | grep -vE 'parse|blmap|lge_dsi_panel_get' \
  | awk '{ s=$0; sub(/^\[ */, "", s); t=s+0; if (t > 0.6 && t < 40) print }' | head -150
