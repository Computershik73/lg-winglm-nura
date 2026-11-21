#!/bin/bash
# Build linux-lg-winglm with pmbootstrap, keep the workspace APKBUILD's checksums in sync
set -e
REL=${1:?pkgrel}
W=$HOME/lg-wing-port/pmaports/device/testing/linux-lg-winglm
A=$(pmbootstrap config aports)/device/testing/linux-lg-winglm
for f in "$W"/*; do sed 's/\r$//' "$f" > "$A/$(basename $f)"; done
pmbootstrap checksum linux-lg-winglm >/dev/null 2>&1
cp "$A/APKBUILD" "$W/APKBUILD"
start=$(date +%s)
pmbootstrap -y build --force linux-lg-winglm > ~/winglm/build-kernel-r$REL.log 2>&1 || { tail -30 ~/winglm/build-kernel-r$REL.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
K=$(pmbootstrap config work)/packages/edge/aarch64
ls -la $K/linux-lg-winglm-4.19.325-r$REL.apk
tar tzf $K/linux-lg-winglm-4.19.325-r$REL.apk 2>/dev/null | grep -E "hci_uart|modules\.dep$" 
