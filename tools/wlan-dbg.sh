#!/bin/sh
# kill a stray pd-mapper left by the strace test (keep the supervised one)
keep=$(cat /run/pd-mapper.pid 2>/dev/null)
for p in $(pgrep -x pd-mapper); do [ "$p" != "$keep" ] && sudo kill $p; done
pgrep -a pd-mapper
qrtr-lookup | awk 'NR==1 || $1 == 4096 || $1 == 64 || $1 == 66 || $1 == 69'
sudo ls /sys/kernel/debug/icnss/
for f in state fw_debug; do [ -e /sys/kernel/debug/icnss/$f ] && { echo "== $f"; sudo cat /sys/kernel/debug/icnss/$f 2>&1 | head -20; }; done
cat /sys/module/icnss/parameters/* 2>/dev/null | head; ls /sys/module/icnss/parameters 2>/dev/null
