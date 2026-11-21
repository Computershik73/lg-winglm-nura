#!/bin/sh
M=/run/msm-firmware-loader/mnt/modem_a
ls $M; ls $M/image | head -50 | tr '\n' ' '; echo
ls -la $M/image/modem_pr 2>&1 | head; ls $M/image/modem_pr/so 2>&1 | head -40 | tr '\n' ' '; echo
find $M -iname "549_*" 2>/dev/null
ls -la /run/msm-firmware-loader/target | head -5; ls /run/msm-firmware-loader/target | wc -l
cat /sys/module/firmware_class/parameters/path; echo
apk info -v 2>/dev/null | grep -E "tqftpserv|msm-firmware"
