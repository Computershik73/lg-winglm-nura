#!/bin/sh
for s in /sys/bus/msm_subsys/devices/*; do echo "$(cat $s/name) $(cat $s/state) $(cat $s/restart_level 2>/dev/null)"; done
sudo python3 /tmp/diagcap.py /tmp/diag3.bin 12 0x1F -- "timeout 10 qmicli -d qrtr://0 --dms-set-operating-mode=online > /tmp/online.txt 2>&1"
cat /tmp/online.txt
python3 /tmp/diagdec.py /tmp/diag3.bin /tmp/qdb.txt > /tmp/diag3.txt
wc -l < /tmp/diag3.txt
grep -iE "oprt|offline|lpm|online|shut|pwr|power|cmph|mmoc|sd_|cm_" /tmp/diag3.txt | cut -c1-200 | awk '!seen[substr($0,9)]++' | head -50
