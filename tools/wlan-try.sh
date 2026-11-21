#!/bin/sh
# Patched tqftpserv, WLAN host files, modem restart, watch icnss/wlan0
R=/home/user/.local/share/abuild/aports
sudo pkill -x tqftpserv; sleep 1
sudo apk add --no-network --repository "$R" tqftpserv=1.3-r10 tqftpserv-openrc=1.3-r10 2>&1 | grep -E 'Upgrading|ERROR' | tail -2
sudo rc-service tqftpserv restart >/dev/null 2>&1
sleep 1; pgrep -a tqftpserv
# CLD host files: the vendor links point to LG's Android persist paths; use the vendor copies
T=/run/msm-firmware-loader/target
V=/run/msm-firmware-loader/mnt/vendor_a
if [ -L $T/wlan ]; then sudo rm $T/wlan; fi
sudo mkdir -p $T/wlan/qca_cld
for f in WCNSS_qcom_cfg.ini bdwlan.bin; do [ -e $T/wlan/qca_cld/$f ] || sudo ln -s $V/etc/wifi/$f $T/wlan/qca_cld/$f; done
ls -la $T/wlan/qca_cld | awk 'NR>1 {print $9, $10, $11}'
# restart the modem
for p in $(pgrep -f '^sleep 2147483647'); do sudo kill $p; done
sleep 5
sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 30
qrtr-lookup | awk 'NR==1 || $1 == 69'
sudo cat /sys/kernel/debug/icnss/stats | head -12
dmesg | tail -300 | grep -iE 'icnss|cnss|wlan|wlfw|bdf|hdd|qca|cld' | grep -v CAM_ | tail -25 | cut -c1-170
ls /sys/class/net | tr '\n' ' '; echo
