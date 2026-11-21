#!/bin/sh
V=/run/msm-firmware-loader/mnt/vendor_a
echo "== vendor ims bits"
ls $V/bin 2>/dev/null | grep -iE "ims|dpm|cnd|qti|rild|cne|dsi" | tr '\n' ' '; echo
ls $V/lib64 2>/dev/null | grep -iE "ims|dcm|rtp|qipcall|dsi|qcmap|ipa_|imsdcm" | tr '\n' ' '; echo
ls $V/etc/init 2>/dev/null | grep -iE "ims|ril|dpm|cne|data" | tr '\n' ' '; echo
echo "== qrtr services"
qrtr-lookup 2>&1 | head -80
echo "== qmicli ims help"
qmicli --help-all 2>/dev/null | grep -iE -- "--ims|--imsa|--imsp|voice-domain|ims" | head -40
qmicli --version | head -1
echo "== modem_pr mcfg"
M=$(ls -d /run/msm-firmware-loader/mnt/modem*/image/modem_pr 2>/dev/null | head -1)
ls $M
find $M -maxdepth 6 -type d -path "*mcfg*" 2>/dev/null | head -60
find $M -name "*.mbn" -path "*mcfg*" 2>/dev/null | wc -l
