#!/bin/sh
# (re)start the VoLTE daemon in the background; this script arrives on stdin,
# so its pattern below does not match the ssh command line
for p in $(pgrep -f '^python3 -u volted.py'); do sudo kill $p; done
sleep 2
sudo sh -c 'cd /tmp/volte && setsid nohup python3 -u volted.py ${1:-3600} > /tmp/volted.log 2>&1 < /dev/null &'
for i in $(seq 1 15); do grep -q "registered for\|failed" /tmp/volted.log 2>/dev/null && break; sleep 1; done
grep -v Deprecat /tmp/volted.log
