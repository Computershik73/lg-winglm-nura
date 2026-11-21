#!/bin/sh
grep -iE ":[^:]*vss[^:]*\.c:|vss init|vss_init" /tmp/qdb.txt | head -40 | cut -c1-200
echo ====
grep -E ":simlock[^:]*\.c:" /tmp/qdb.txt | grep -iE "vss|wait|lge" | head -20 | cut -c1-200
