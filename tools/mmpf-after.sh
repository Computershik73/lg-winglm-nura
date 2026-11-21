#!/bin/sh
# usage: mmpf-after.sh START_REGEX [N]
grep -aE "MMPF|vss_ims|LRtp|VAdaptor|QCT_VS|QCT_CVD|PsIface|MMPFSocket|vagent|cvd|VS_|dss|ps_iface|vs_|voice" /tmp/mmpf-diag.txt \
 | grep -avE "PROCESS REQUEST CALLBACK|Enter qmi_vss_lge_ims_media_req|Add a Msg successfully|MMPF_TaskThread\] 2 / 2|coex_algos|MMPFEventHandler|MMPFTrace" \
 | cut -c1-210 | sed -n "/$1/,\$p" | head -${2:-250}
