#!/bin/sh
# install the modem-media daemon modules (test deploy, packaged later) and restart
cd /tmp/volte
sudo cp mmpf.py modemmedia.py volted.py sdp.py media.py /usr/lib/winglm-volte/
sudo rc-service winglm-volte restart 2>&1 | tail -1
for i in $(seq 1 90); do
	sudo grep -q "IMS registered\|modem media" /var/log/winglm-volte.trace 2>/dev/null && \
	sudo tail -n 40 /var/log/winglm-volte.trace | grep -q "IMS registered" && break
	sleep 2
done
sudo grep -aE "modem media|IMS registered|Traceback|Error|error" /var/log/winglm-volte.trace | tail -8 | cut -c1-200
cat /run/winglm-volte/status
