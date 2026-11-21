#!/bin/sh
M=$(ls -d /run/msm-firmware-loader/mnt/modem*/image/modem_pr 2>/dev/null | head -1)
V=/run/msm-firmware-loader/mnt/vendor_a
echo "== mbns"
cd $M/mcfg/configs && find . -name "*.mbn" -exec ls -la {} \; | awk '{print $5, $9}'
echo "== pdc"
sudo qmicli -d qrtr://0 --pdc-list-configs=software 2>&1 | head -60
sudo qmicli -d qrtr://0 --pdc-get-selected-config=software 2>&1 | head
sudo qmicli -d qrtr://0 --pdc-list-configs=platform 2>&1 | head -30
echo "== ims qmi tries"
sudo timeout 10 qmicli -d qrtr://0 --imsa-get-ims-registration-status 2>&1 | head -5
sudo timeout 10 qmicli -d qrtr://0 --ims-get-ims-services-enabled-setting 2>&1 | head -5
echo "== vss ims"
ls -la $V/bin/hw 2>/dev/null | grep -iE "vss|ims|lge"
cat $V/etc/init/vendor.lge.hardware.vss_ims@1.0-service.rc
ls $V/etc/init | head -100 | tr '\n' ' '
