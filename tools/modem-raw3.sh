#!/bin/sh
sudo timeout 20 qmicli -d qrtr://0 -v --dms-get-operating-mode > /tmp/qm.log 2>&1
grep -n -iE "raw|tlv|received|<<<" /tmp/qm.log | tail -20 | cut -c1-200
echo == cmdline
tr ' ' '\n' < /proc/cmdline | grep -vE "^(console|pmos_|root|init|video)" | sort | tr '\n' ' '; echo
echo == qdb
find /run/msm-firmware-loader -maxdepth 6 \( -iname "*.qdb" -o -iname "*qsr*" \) 2>/dev/null | head
ls /run/msm-firmware-loader/ 2>/dev/null; ls /run/msm-firmware-loader/mnt 2>/dev/null
