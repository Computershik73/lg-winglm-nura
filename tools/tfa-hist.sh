#!/bin/sh
dmesg | grep -E "Failed starting device|tfa_dev_start: tfa98xx_log_start_cnt" | sed 's/^\[ *\([0-9]*\)\..*\] /\1 /' | awk '{t=$1; sub(/^[0-9]+ /,""); print int(t/10)*10, $0}' | cut -c1-80 | uniq -c | tail -20
