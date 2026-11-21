#!/bin/sh
F=/tmp/diag2.txt
grep -E " tftp[^ ]*\.c:" $F | cut -c1-200 | awk '!seen[substr($0,9)]++' | head -50
echo == rfc mbn mentions in qdb
grep -iE "rfc.*mbn|mbn.*rfc|rfc_mbn" /tmp/qdb.txt | cut -d: -f2- | cut -c1-180 | head -20
