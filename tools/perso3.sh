#!/bin/sh
F=/tmp/diag4.txt
grep -E " (simlock|mmgsdi|qmi_vss|lge_gsdi|qmi_uim)[^ ]*\.c(pp)?:" $F | awk '$1>=4.834' | grep -vE "mmgsdicache|mmgsdi_uim_uicc|mmgsdiutil.c:4(156|357|051|573)|mmgsdi_nv.c:2276|mmgsdi.c:(3777|4693|5327)" | cut -c1-200 | head -60
echo == waiting lines times
grep "waiting vss init" $F | awk '{print $1}' | tr '\n' ' '
