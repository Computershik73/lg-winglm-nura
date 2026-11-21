#!/bin/sh
f=/run/msm-firmware-loader/mnt/modem_a/image/saipan/qdsp6m.qdb
head -c 256 $f | od -A x -t x1 -c | head -24
python3 -c "
import zlib,sys
d=open('$f','rb').read()
for off in range(0,1024):
    if d[off:off+2] in (b'\x78\x9c',b'\x78\xda',b'\x78\x01'):
        try:
            z=zlib.decompressobj(); out=z.decompress(d[off:off+200000])
            print('zlib at',off,len(out)); print(out[:600]); break
        except Exception as e: pass
"
which python3 strace xxd hexdump 2>&1 | head
