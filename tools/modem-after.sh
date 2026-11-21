#!/bin/sh
Q="sudo timeout 20 qmicli -d qrtr://0"
for i in 1 2 3; do $Q --dms-get-operating-mode 2>&1 | grep Mode; sleep 3; done
$Q --uim-get-card-status 2>&1 | grep -E "Card state|Application state|Personalization" | head -4
$Q --nas-get-serving-system 2>&1 | head -8
mmcli -L 2>&1
M=$(mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | head -1 | cut -d/ -f2)
[ -n "$M" ] && mmcli -m $M 2>&1 | grep -E "state|power|failed|access tech|signal|operator|registration|sim" | head -20
