#!/bin/sh
R=/home/user/.local/share/abuild/aports
sudo apk add --no-network --repository "$R" pd-mapper=1.1-r1 pd-mapper-openrc=1.1-r1 2>&1 | grep -E 'Upgrading|ERROR' | tail -2
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r16.apk /tmp/device-lg-winglm-phosh-1-r16.apk /tmp/device-lg-winglm-dsp-1-r16.apk 2>&1 | grep -E 'Installing|Upgrading|ERROR|OK:' | tail -5
sudo rm -f /etc/udev/rules.d/90-winglm-modem.rules
rc-update show -v 2>/dev/null | grep -E 'qrtr-ns|pd-mapper|winglm|modemmanager|tqftpserv|msm-firmware'
ls /etc/init.d/winglm-* /usr/libexec/winglm-dsp-setup /usr/bin/winglm-wlfw-bdf /usr/lib/udev/rules.d/90-winglm-modem.rules
