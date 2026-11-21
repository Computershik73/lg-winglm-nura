#!/bin/sh
sudo python3 /tmp/diagcap.py /tmp/diag5.bin 8 0x1F -- "python3 /tmp/qmivss.py 800 0x602 1 > /tmp/vss.txt 2>&1"
cat /tmp/vss.txt
python3 /tmp/diagdec.py /tmp/diag5.bin /tmp/qdb.txt > /tmp/diag5.txt
grep -iE "vss|simlock|perso" /tmp/diag5.txt | grep -v "waiting vss init" | cut -c1-200 | head -30
grep -c "waiting vss init" /tmp/diag5.txt
sudo timeout 10 qmicli -d qrtr://0 --uim-get-card-status 2>&1 | grep -E "Application state|Personalization" | head -2
