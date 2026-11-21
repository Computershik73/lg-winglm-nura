#!/bin/sh
grep -iE "vss.?init|init.?vss|vss_ready|vss ready|resim.*(ready|init|complete)|rsu.*(init|ready)" /tmp/qdb.txt | cut -d: -f2- | cut -c1-180 | head -30
echo == resim server
grep -E ":qmi_vss_resim_server\.c:" /tmp/qdb.txt | cut -d: -f4- | cut -c1-170 | head -60
