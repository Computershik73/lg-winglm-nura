#!/bin/sh
F=/tmp/diag2.txt
grep -E " (rfc|rfm|rfcommon|lge_rf|rf_|nvm|mcfg|pdc|nv_)[^ ]*\.(c|cpp):" $F | grep -vE "Sawless" | cut -c1-210 | awk '!seen[substr($0,9)]++' | head -90
echo == pdc
sudo timeout 20 qmicli -d qrtr://0 --pdc-list-configs=platform 2>&1 | grep -E "Description|Status|ID:" | head -30
