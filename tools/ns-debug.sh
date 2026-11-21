#!/bin/sh
sudo rc-service tqftpserv stop >/dev/null 2>&1; sudo rc-service pd-mapper stop >/dev/null 2>&1; sudo rc-service qrtr-ns stop >/dev/null 2>&1
sudo pkill -x qrtr-ns; sleep 1
pgrep -a qrtr-ns
sudo setsid qrtr-ns -f -v 1 > /tmp/qrtr-ns.log 2>&1 < /dev/null &
sleep 1
sudo setsid pd-mapper > /tmp/pd-mapper.log 2>&1 < /dev/null &
sudo setsid tqftpserv > /tmp/tqftp.log 2>&1 < /dev/null &
sleep 2
qrtr-lookup | awk 'NR==1 || $4 == 1' | grep -v DIAG
echo "== ns log"; head -40 /tmp/qrtr-ns.log | cut -c1-160
echo "== pd-mapper"; cat /tmp/pd-mapper.log | head -5
