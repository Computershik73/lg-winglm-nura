#!/bin/sh
F=/tmp/diag2.txt
grep -E " (simlock|mmgsdi|uim|lge_gsdi|qmi_vss)[^ ]*\.c(pp)?:" $F | grep -iE "perso|simlock|vss|ready|state|app|subscription|status|fail|err|wait|block" | cut -c1-190 | awk '!seen[substr($0,9)]++' | head -70
