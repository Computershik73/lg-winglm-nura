#!/bin/sh
ls -la /run/msm-firmware-loader/target | grep -E "^d|^l.*/$" ; ls -la /run/msm-firmware-loader/target | grep -c "^l"
F=$(which msm-firmware-loader 2>/dev/null || ls /usr/sbin/msm-firmware-loader* /usr/bin/msm-firmware-loader* 2>/dev/null | head -1); echo $F
grep -nE "ln |find|for |image|maxdepth|target" $F | head -40
cat /etc/init.d/winglm-modem | head -40
