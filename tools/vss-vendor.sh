#!/bin/sh
V=/run/msm-firmware-loader/mnt/vendor_a
ls $V | tr '\n' ' '; echo
grep -rlsaE "vss_resim|VSS_RESIM|qmi_vss|vss_qmi|resim" $V/bin $V/lib64 $V/lib $V/etc 2>/dev/null | head -20
echo == init rc
grep -rlsE "vss|resim|rsu" $V/etc/init 2>/dev/null | head; 
