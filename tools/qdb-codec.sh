#!/bin/sh
grep -aE ":(MMPF[A-Za-z_]*|LRtp[A-Za-z_]*|MMPFNode[A-Za-z_]*|MMPF_Voice[A-Za-z_]*)\.(cpp|c):" /tmp/qdb.txt | grep -aiE "codec|amr|evs|payload|ptime|octet|bandwidth|eMode|property|setProperty|TxSource|vocoder|cvd|vs_|voice" | cut -d: -f5- | cut -c1-200 | sort -u | head -150
