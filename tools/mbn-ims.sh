#!/bin/sh
M=$(ls -d /run/msm-firmware-loader/mnt/modem*/image/modem_pr 2>/dev/null | head -1)
cd $M/mcfg/configs/mcfg_sw/generic
for f in Korea/ROW/Commercial Korea/SKT/Commercial NA/TMO/Commercial NA/ATT/VoLTE common/Default/Default; do
	echo "== $f: $(strings -n 6 $f/mcfg_sw.mbn | grep -c -i ims) ims strings"
	strings -n 6 $f/mcfg_sw.mbn | grep -i -E "ims|volte|voice_domain|qipcall|sms_domain" | sort -u | head -40 | tr '\n' ' '
	echo
done
