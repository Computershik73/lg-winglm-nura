#!/bin/sh
# install r32 (IMS re-authentication fix + other session's lid/Calls changes),
# drop the registration test knobs, restart only winglm-volte
sudo rm -f /etc/winglm-volte/expires /etc/winglm-volte/refresh /etc/winglm-volte/test-reregister
cd /tmp && sudo apk add --no-network --allow-untrusted ./device-lg-winglm-1-r32.apk ./device-lg-winglm-phosh-1-r32.apk \
	./device-lg-winglm-dsp-1-r32.apk ./device-lg-winglm-volte-1-r32.apk 2>&1 | tail -3
apk info -v 2>/dev/null | grep device-lg-winglm
apk info -W /etc/UPower/UPower.conf.d/90-winglm.conf 2>&1 | tail -1
apk info -W /usr/share/glib-2.0/schemas/90_winglm-calls.gschema.override 2>&1 | tail -1
cmp /tmp/volte/imsreg2.py /usr/lib/winglm-volte/imsreg2.py && echo "imsreg2 = tested version"
ls /etc/winglm-volte/ 2>/dev/null
echo "trace line $(sudo wc -l < /var/log/winglm-volte.trace)"
sudo rc-service winglm-volte restart 2>&1 | tail -1
