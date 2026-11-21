#!/bin/bash
# Build device-lg-winglm with pmbootstrap (noarch scripts only) and copy the apks to the phone
set -e
REL=$1
W=/mnt/c/MICD/profiles/d19bc6bc-1286-4caf-9fe1-c0fc5c4175a3/scratch-workspaces/7f4c33e3-713d-4694-9eaa-57d6e1528aa0/4559bdd3-f3f8-4a6b-afb9-1e62cbd0b548/scratch-2026-11-13-581527/pmaports/device/testing/device-lg-winglm
A=$(pmbootstrap config aports)/device/testing/device-lg-winglm
cp -r "$W"/. "$A"/
pmbootstrap checksum device-lg-winglm >/dev/null 2>&1
cp "$A/APKBUILD" "$W/APKBUILD"
pmbootstrap -y build device-lg-winglm 2>&1 | tail -1
K=$HOME/.local/var/pmbootstrap/packages/edge
scp -q -o BatchMode=yes $(ls $K/*/device-lg-winglm-1-r$REL.apk $K/*/device-lg-winglm-phosh-1-r$REL.apk $K/*/device-lg-winglm-dsp-1-r$REL.apk $K/*/device-lg-winglm-volte-1-r$REL.apk 2>/dev/null) user@172.16.42.1:/tmp/
echo "copied r$REL"
