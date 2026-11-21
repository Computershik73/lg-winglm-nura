#!/bin/sh
Q="sudo timeout 20 qmicli -d qrtr://0"
$Q --dms-get-operating-mode 2>&1 | grep Mode
$Q --uim-get-card-status 2>&1 | grep -E "Card state|Application state|Personalization|PIN1 state" | head -5
$Q --nas-get-serving-system 2>&1 | head -14
$Q --nas-get-signal-info 2>&1 | head -12
grep -iE "simlock|perso|vss" /tmp/diag3.txt | cut -c1-180 | awk '!seen[substr($0,9)]++' | head -20
