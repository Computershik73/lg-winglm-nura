#!/bin/sh
F=/tmp/diag2.txt
grep -E " (rfc|rfm|lge_rf|rfcommon|rf_hal|rfdevice|rfnv|nv_manager|nvta)[^ ]*\.(c|cpp):|HWID|hwid|FSID|EEPROM" $F | grep -vE "Sawless" | cut -c1-230 | awk '!seen[substr($0,9)]++' | sed -n '1,80p'
