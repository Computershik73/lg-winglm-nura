#!/bin/sh
sudo rc-service winglm-modem stop >/dev/null 2>&1
sudo rc-service winglm-rmtfs stop >/dev/null 2>&1; sleep 1
sudo sh -c "setsid rmtfs -v -o /var/lib/rmtfs > /tmp/rmtfs.log 2>&1 < /dev/null &"
sleep 2
sudo rc-service winglm-modem start >/dev/null 2>&1
sleep 35
echo "mode: $(sudo timeout 10 qmicli -d qrtr://0 --dms-get-operating-mode 2>&1 | grep Mode)"
grep -viE "^\s*$" /tmp/rmtfs.log | grep -iE "open|error|fail|unknown|partition|caller|name|iovec" | sort | uniq -c | sort -rn | head -20 | cut -c1-150
wc -l /tmp/rmtfs.log
sudo pkill -x rmtfs; sleep 1
sudo rc-service winglm-rmtfs start >/dev/null 2>&1
