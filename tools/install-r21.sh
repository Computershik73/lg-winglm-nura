#!/bin/sh
grep -E "flash_kernel_on_update" /etc/deviceinfo /usr/share/deviceinfo/* 2>/dev/null | head -2
sudo rc-service bluetooth stop >/dev/null 2>&1
sudo pkill -f "python3 /tmp/winglm-bt$"; sleep 1
sudo rmmod hci_uart 2>/dev/null; lsmod | grep -c hci_uart
apk info -W /etc/conf.d/polkit 2>&1 | tail -1
sudo rm -f /etc/conf.d/polkit
sudo apk add --allow-untrusted --no-network /tmp/linux-lg-winglm-4.19.325-r5.apk /tmp/device-lg-winglm-1-r21.apk /tmp/device-lg-winglm-phosh-1-r21.apk /tmp/device-lg-winglm-dsp-1-r21.apk 2>&1 | grep -vE "^\s*$" | tail -6
apk info -v 2>/dev/null | grep -E "^(linux-lg-winglm|device-lg-winglm)"
ls -la /lib/modules/$(uname -r)/kernel/drivers/bluetooth/
cat /etc/conf.d/polkit | tail -3
rc-update show -v | grep -E "polkit|bluetooth|winglm-bt"
sudo modprobe hci_uart && echo "modprobe ok"; dmesg | tail -3 | grep -iE "hci|uart|version"
sudo rc-service winglm-bt start 2>&1 | tail -1; sleep 6; tail -3 /var/log/winglm-bt.log
sudo rc-service bluetooth start 2>&1 | tail -1; sleep 3
bluetoothctl show | grep -E "Controller|Powered"
