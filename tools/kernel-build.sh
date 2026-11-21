#!/bin/bash
# Build linux-lg-winglm with pmbootstrap, keep the workspace APKBUILD's checksums in sync
set -e
W=/mnt/c/MICD/profiles/d19bc6bc-1286-4caf-9fe1-c0fc5c4175a3/scratch-workspaces/7f4c33e3-713d-4694-9eaa-57d6e1528aa0/4559bdd3-f3f8-4a6b-afb9-1e62cbd0b548/scratch-2026-11-13-581527/pmaports/device/testing/linux-lg-winglm
A=$(pmbootstrap config aports)/device/testing/linux-lg-winglm
for f in "$W"/*; do sed 's/\r$//' "$f" > "$A/$(basename $f)"; done
pmbootstrap checksum linux-lg-winglm >/dev/null 2>&1
cp "$A/APKBUILD" "$W/APKBUILD"
start=$(date +%s)
pmbootstrap -y build --force linux-lg-winglm > ~/winglm/build-kernel-r6.log 2>&1 || { tail -30 ~/winglm/build-kernel-r5.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
K=$(pmbootstrap config work)/packages/edge/aarch64
ls -la $K/linux-lg-winglm-4.19.325-r6.apk
tar tzf $K/linux-lg-winglm-4.19.325-r6.apk 2>/dev/null | grep -E "hci_uart|modules\.dep$" 
