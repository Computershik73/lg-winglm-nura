#!/bin/sh
V=/run/msm-firmware-loader/mnt/vendor_a
find $V/bin $V/lib64 $V/lib $V/etc -iname "*vss*" 2>/dev/null | head -30
find $V/lib64 -iname "*lg*qmi*" -o -iname "*qmi*lg*" -o -iname "*lge*ril*" -o -iname "*lgril*" 2>/dev/null | head -20
