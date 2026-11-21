#!/bin/sh
# usage: sh -s <from-seconds> <egrep-pattern> [max-lines]
FROM=$1; PAT=$2; MAX=${3:-60}
sudo dmesg | awk -v m="$FROM" '{ s=$0; sub(/^\[ */, "", s); if (s+0 >= m) print }' \
	| grep -E "$PAT" | head -n "$MAX" | cut -c1-160
