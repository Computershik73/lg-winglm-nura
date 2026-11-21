#!/bin/sh
F=/tmp/diag4.txt
grep -c "waiting vss init" $F
grep -E " (simlock|mmgsdi|qmi_vss|lge_gsdi|simlock_[a-z0-9_]*)[^ ]*\.c(pp)?:" $F | awk '$1>=4.8' | cut -c1-200 | head -80
