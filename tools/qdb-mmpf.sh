#!/bin/sh
f=$(ls /run/msm-firmware-loader/mnt/modem*/image/saipan/qdsp6m.qdb | head -1)
[ -s /tmp/qdb.txt ] || python3 -c "
import zlib
d=open('$f','rb').read()
open('/tmp/qdb.txt','wb').write(zlib.decompressobj().decompress(d[64:]))
"
echo "== source files (MMPF/LRTP/VSS/IMS media), message counts"
awk -F: '{print $5}' /tmp/qdb.txt | grep -iE "mmpf|lrtp|rtp|vss|ims|media|codec|amr|evs|jitter" | sort | uniq -c | sort -rn | head -60
