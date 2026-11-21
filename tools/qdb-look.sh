#!/bin/sh
grep -E "^(12370|172127):" /tmp/qdb.txt | cut -c1-200
grep -m3 -n "update_msg_mask" /tmp/qdb.txt | cut -c1-200
sed -n '/<MtraceContent>/,+3p;/<QtraceStrContent>/,+3p' /tmp/qdb.txt | cut -c1-200
