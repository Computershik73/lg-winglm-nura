#!/bin/sh
Q="sudo timeout 20 qmicli -d qrtr://0"
$Q --nas-get-serving-system 2>&1 | grep -E "Registration|CS:|PS:|\[0\]|MCC|MNC|Description|Roaming status"
$Q --nas-get-signal-info 2>&1 | head -8
mmcli -L 2>&1
pgrep -a ModemManager; rc-service modemmanager status 2>&1 | tail -1
