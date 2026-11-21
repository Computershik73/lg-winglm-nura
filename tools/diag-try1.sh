#!/bin/sh
sudo python3 /tmp/diagcap.py /tmp/diag1.bin 8 0x1F -- "timeout 10 qmicli -d qrtr://0 --dms-set-operating-mode=online > /tmp/online.txt 2>&1"
cat /tmp/online.txt
python3 - <<'PY'
import struct, collections
d=open('/tmp/diag1.bin','rb').read(); i=0; c=collections.Counter(); first={}
while i+12<=len(d):
    ts,ln=struct.unpack_from('<dI',d,i); p=d[i+12:i+12+ln]; i+=12+ln
    k=p[:1].hex() if not p.startswith(b'BADCRC') else 'bad'
    c[k]+=1; first.setdefault(k,[]).append(p[:48].hex()) if len(first.get(k,[]))<3 else None
print(c.most_common())
for k,v in first.items():
    for x in v: print(k, x)
PY
