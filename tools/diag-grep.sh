#!/bin/sh
F=${1:-/tmp/diag2.txt}
echo "== oprt/offline/lpm/ftm"
grep -iE "oprt|offline|[^a-z]lpm|ftm|online|power.?up|pwr_up|rf_init|rfm_init|rfc_|rf card|rf_card|hw_id|hwid" $F | cut -c1-200 | awk '!seen[substr($0,9)]++' | head -60
echo "== vss/simlock/lge"
grep -iE "vss|simlock|\[LGE|lge_" $F | cut -c1-200 | awk '!seen[substr($0,9)]++' | head -40
echo "== files"
awk '{for(i=1;i<=NF;i++) if ($i ~ /\.(c|cpp):[0-9]+$/) {split($i,a,":"); print a[1]}}' $F | sort | uniq -c | sort -rn | head -50 | tr '\n' ' '
