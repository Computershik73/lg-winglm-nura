#!/bin/sh
sudo python3 /tmp/diagcap.py /tmp/diag4.bin 70 0x1F -- "rc-service winglm-modem restart > /tmp/mr.txt 2>&1; sleep 20; timeout 10 qmicli -d qrtr://0 --dms-set-operating-mode=online > /tmp/online.txt 2>&1"
cat /tmp/online.txt
python3 /tmp/diagdec.py /tmp/diag4.bin /tmp/qdb.txt > /tmp/diag4.txt
wc -l < /tmp/diag4.txt
grep -iE "vss|simlock\.c|simlock_modem\.c|perso|rsu" /tmp/diag4.txt | cut -c1-190 | awk '!seen[substr($0,9)]++' | head -60
