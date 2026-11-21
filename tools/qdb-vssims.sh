#!/bin/sh
grep -aE "vss_ims|qmi_vss|lge_ims|VSS_IMS" /tmp/qdb.txt | cut -d: -f4- | cut -c1-220 | sort -u | head -80
echo ---
grep -aE "MMPF\.cpp:" /tmp/qdb.txt | cut -d: -f4- | cut -c1-200 | sort -u | head -80
