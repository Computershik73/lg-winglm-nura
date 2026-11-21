#!/bin/sh
grep -E ":qmi_vss_common_service\.c:" /tmp/qdb.txt | awk -F: '$4>=3600 && $4<=3900' | cut -d: -f4- | cut -c1-170
echo == handlers
grep -E ":qmi_vss_common_service\.c:" /tmp/qdb.txt | grep -iE "handler|Enter|req_v0|msg_id|init" | cut -d: -f4- | cut -c1-150 | sort -t: -k1n | head -80
echo == core server
grep -E ":qmi_core_server\.c:" /tmp/qdb.txt | cut -d: -f4- | cut -c1-150 | sort -t: -k1n | head -30
