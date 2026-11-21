#!/bin/sh
python3 /tmp/diagdec.py /tmp/diag1.bin /tmp/qdb.txt > /tmp/diag1.txt
wc -l /tmp/diag1.txt
grep -vE "diag_update_msg_mask|update_msg_mask" /tmp/diag1.txt | head -60 | cut -c1-230
