#!/bin/sh
T=/run/msm-firmware-loader/target
[ -e $T/modem_pr ] || sudo ln -s /run/msm-firmware-loader/mnt/modem_a/image/modem_pr $T/modem_pr
ls -la $T/modem_pr/so/549_6_0.mbn
sudo rc-service winglm-modem restart >/dev/null 2>&1
sleep 25
Q="sudo timeout 20 qmicli -d qrtr://0"
$Q --dms-get-operating-mode 2>&1 | grep Mode
$Q --dms-get-band-capabilities 2>&1 | head -4 | cut -c1-200
$Q --dms-get-capabilities 2>&1 | grep Networks
$Q --uim-get-card-status 2>&1 | grep -E "Application state" | head -2
