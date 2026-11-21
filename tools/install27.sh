#!/bin/sh
cd /tmp && sudo apk add --no-network --allow-untrusted ./device-lg-winglm-1-r27.apk ./device-lg-winglm-phosh-1-r27.apk ./device-lg-winglm-dsp-1-r27.apk 2>&1 | tail -3
rc-update show default | grep -E "vss|modem"
sudo rc-service winglm-vss start 2>&1 | tail -1
sleep 2; cat /var/log/winglm-vss.log
