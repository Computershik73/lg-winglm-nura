#!/bin/sh
f=$(ls /run/msm-firmware-loader/mnt/modem*/image/saipan/qdsp6m.qdb | head -1)
[ -s /tmp/qdb.txt ] || python3 -c "
import zlib
d=open('$f','rb').read()
open('/tmp/qdb.txt','wb').write(zlib.decompressobj().decompress(d[64:]))
"
wc -l < /tmp/qdb.txt
echo "== source files matching ims/sip/dcm/qipcall (count of msgs)"
awk -F: '{print $5}' /tmp/qdb.txt | grep -iE "ims|qipcall|sip|dcm|qvp|rtp|volte|regmgr|qpdpl|presence" | sort | uniq -c | sort -rn | head -70
echo "== ssids of those"
grep -iE ":[^:]*(imsa|ims_|qipcall|regmgr|dcm)[^:]*\.c:" /tmp/qdb.txt | awk -F: '{print $3}' | sort -n | uniq -c | head
ls /tmp/diagcap.py /tmp/diagdec.py 2>&1
