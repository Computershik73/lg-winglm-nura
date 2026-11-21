#!/bin/sh
sudo timeout 20 qmicli -d qrtr://0 -v --dms-get-operating-mode > /tmp/qm.log 2>&1
awk '/Received message/ {f=1} f' /tmp/qm.log | head -40
echo == diag
ls -la /dev/diag* 2>&1; grep -i diag /proc/devices; zcat /proc/config.gz 2>/dev/null | grep -iE "DIAG|CONFIG_QCOM_SMEM=|MSM_SUBSYS" | head
echo == qrtr services
sudo timeout 10 qrtr-lookup 2>/dev/null | head -80
