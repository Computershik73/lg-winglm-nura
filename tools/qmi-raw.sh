#!/bin/sh
sudo timeout 30 qmicli -d qrtr://0 -v --dms-get-operating-mode > /tmp/qm.log 2>&1
awk '/Received message/ {f=1} f' /tmp/qm.log | grep -E "message|type|length|value" | head -30
