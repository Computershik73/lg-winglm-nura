#!/bin/sh
sudo python3 /tmp/diagcap.py /tmp/diag2.bin 55 0x1F -- "rc-service winglm-modem restart > /tmp/mr.txt 2>&1"
python3 /tmp/diagdec.py /tmp/diag2.bin /tmp/qdb.txt > /tmp/diag2.txt
wc -l /tmp/diag2.txt
echo "== E/F"
grep -E "^ *[0-9.]+ (\[pd[0-9]+\] )?[EF] " /tmp/diag2.txt | grep -v "Unable to allocate the memory to log" | cut -c1-220 | awk '!seen[substr($0,9)]++' | head -70
