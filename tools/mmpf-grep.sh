#!/bin/sh
# usage: mmpf-grep.sh REGEX [N]  - unique MMPF/DSS lines matching REGEX
grep -aiE "$1" /tmp/mmpf-diag.txt | grep -aE " (5|5000|17|8500) " | grep -av coex | cut -c1-210 \
 | awk '{k=$0; sub(/^ *[0-9.]+ +/, "", k); if (!(k in seen)) {seen[k]=1; print}}' | head -${2:-90}
