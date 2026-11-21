#!/bin/sh
# usage: mmpf-diag.sh PROBE_SCRIPT [SECONDS]
cd /tmp/volte
P=${1:-mmpfprobe.py}
S=${2:-12}
sudo python3 diagcap.py /tmp/mmpf-diag.bin $S 0x1F -- python3 -u /tmp/volte/$P > /tmp/mmpf-probe.out 2>&1
cat /tmp/mmpf-probe.out
python3 diagdec.py /tmp/mmpf-diag.bin /tmp/qdb.txt > /tmp/mmpf-diag.txt 2>/dev/null
echo "== decoded lines: $(wc -l < /tmp/mmpf-diag.txt)"
grep -aE "MMPF|vss_ims|LRtp|VAdaptor|QCT_VS|QCT_CVD|PsIface|MMPFSocket" /tmp/mmpf-diag.txt | cut -c1-230 | head -${3:-120}
