#!/bin/sh
Q="sudo timeout 20 qmicli -d qrtr://0"
uptime
$Q --dms-get-operating-mode 2>&1 | tail -3
$Q --uim-get-card-status 2>&1 | head -40
$Q --dms-get-capabilities 2>&1 | tail -8
$Q --nas-get-system-selection-preference 2>&1 | tail -12
mmcli -L 2>&1
rc-status | grep -iE "modem|rmtfs|q6v|tqftp"
