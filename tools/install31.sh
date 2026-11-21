#!/bin/sh
# install r31 (modem media + earpiece Class-H) over the hand-deployed files
cd /tmp && sudo apk add --no-network --allow-untrusted ./device-lg-winglm-1-r31.apk ./device-lg-winglm-phosh-1-r31.apk \
	./device-lg-winglm-dsp-1-r31.apk ./device-lg-winglm-volte-1-r31.apk 2>&1 | tail -3
apk info -v 2>/dev/null | grep device-lg-winglm
ls /usr/lib/winglm-volte/
grep -c CLS_H_ULP /usr/share/alsa/ucm2/conf.d/lito-mtp-snd-ca/VoiceCall.conf /usr/share/alsa/ucm2/conf.d/lito-mtp-snd-ca/HiFi.conf
sudo rc-service winglm-volte restart 2>&1 | tail -1
for i in $(seq 1 50); do sudo tail -n 3 /var/log/winglm-volte.trace | grep -q "IMS registered" && break; sleep 3; done
sudo tail -n 2 /var/log/winglm-volte.trace
cat /run/winglm-volte/status
