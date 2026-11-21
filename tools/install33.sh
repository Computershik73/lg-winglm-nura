#!/bin/sh
# r33: winglm-voice, PulseAudio session check, VoLTE CS fallback; VoLTE back on
cd /tmp && sudo apk add --no-network --allow-untrusted ./device-lg-winglm-1-r33.apk ./device-lg-winglm-phosh-1-r33.apk \
	./device-lg-winglm-dsp-1-r33.apk ./device-lg-winglm-volte-1-r33.apk 2>&1 | tail -2
apk info -v 2>/dev/null | grep -E '^device-lg-winglm|^calls-51'
rc-update show default | grep -E 'q6voiced|winglm-voice'
apk info -W /usr/bin/winglm-voice /usr/libexec/winglm-pulse-session 2>&1
sudo rm -f /var/lib/winglm-volte/ipa-guard
sudo rc-service winglm-voice restart 2>&1 | tail -1
sudo rc-service winglm-volte restart 2>&1 | tail -1
for i in $(seq 1 40); do grep -q "ims=registered" /run/winglm-volte/status && break; sleep 3; done
sleep 35
cat /run/winglm-volte/status
sudo grep -aE "GNOME Calls REGISTER|IMS registered|start failed|cell location" /var/log/winglm-volte.trace | tail -5 | cut -c1-110
