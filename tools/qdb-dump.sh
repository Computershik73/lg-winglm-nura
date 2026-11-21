#!/bin/sh
f=/run/msm-firmware-loader/mnt/modem_a/image/saipan/qdsp6m.qdb
python3 -c "
import zlib
d=open('$f','rb').read()
out=zlib.decompressobj().decompress(d[64:])
open('/tmp/qdb.txt','wb').write(out)
"
wc -l /tmp/qdb.txt
grep -vn "^#" /tmp/qdb.txt | head -12 | cut -c1-220
echo ...
grep -n "^<" /tmp/qdb.txt | head -10 | cut -c1-200
grep -ciE "rfc|rf_card|hwid" /tmp/qdb.txt
grep -iE "rfc.*(not|fail|invalid|unsupport|mismatch)" /tmp/qdb.txt | head -20 | cut -c1-220
