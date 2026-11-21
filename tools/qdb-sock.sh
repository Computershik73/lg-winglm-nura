#!/bin/sh
f=$(ls /run/msm-firmware-loader/mnt/modem*/image/saipan/qdsp6m.qdb | head -1)
[ -s /tmp/qdb.txt ] || python3 -c "
import zlib
d=open('$f','rb').read()
open('/tmp/qdb.txt','wb').write(zlib.decompressobj().decompress(d[64:]))
"
grep -aiE "socketpos|sockpos|socket_pos|bridge|SOCKET_IF|singleip|single ip|CP_IP|IpAddrOfCP|MMPF_CP_MSG|MMPF_CP_IND" /tmp/qdb.txt | cut -c1-220 | sort -u | head -80
