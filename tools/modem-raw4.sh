#!/bin/sh
Q="sudo timeout 20 qmicli -d qrtr://0"
awk '/Get Operating Mode/,/Release CID/' /tmp/qm.log | grep -E "message|type|length|value|translated" | head -30
$Q --nas-get-system-info 2>&1 | head -20
$Q --nas-get-serving-system 2>&1 | head -10
$Q --dms-get-activation-state 2>&1 | tail -2
$Q --dms-get-power-state 2>&1 | tail -3
f=/run/msm-firmware-loader/mnt/modem_a/image/saipan/qdsp6m.qdb
ls -la $f; head -c 64 $f | od -A x -t x1z | head -5
ls /run/msm-firmware-loader/mnt/modem_a/image/saipan/ | head -30
