#!/bin/bash
# Build device-lg-winglm with pmbootstrap (noarch scripts only) and copy the apks to the phone
set -e
REL=$1
W=$HOME/lg-winglm-nura/pmaports/device/testing/device-lg-winglm
A=$(pmbootstrap config aports)/device/testing/device-lg-winglm
cp -r "$W"/. "$A"/
pmbootstrap checksum device-lg-winglm >/dev/null 2>&1
cp "$A/APKBUILD" "$W/APKBUILD"
pmbootstrap -y build device-lg-winglm 2>&1 | tail -1
K=$HOME/.local/var/pmbootstrap/packages/edge
scp -q -o BatchMode=yes $(ls $K/*/device-lg-winglm-1-r$REL.apk $K/*/device-lg-winglm-phosh-1-r$REL.apk $K/*/device-lg-winglm-dsp-1-r$REL.apk $K/*/device-lg-winglm-volte-1-r$REL.apk 2>/dev/null) user@172.16.42.1:/tmp/
echo "copied r$REL"
