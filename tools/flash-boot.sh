#!/bin/sh
# usage: sh -s IMG SHA256 ; writes IMG to boot_a, verifies by readback
set -e
IMG=$1
WANT=$2
DEV=$(readlink -f /dev/disk/by-partlabel/boot_a)
echo "target $DEV <- $IMG"
[ "$(sha256sum "$IMG" | cut -d' ' -f1)" = "$WANT" ] || { echo "image hash mismatch"; exit 1; }
SIZE=$(stat -c %s "$IMG")
sudo dd if="$IMG" of="$DEV" bs=4096 conv=fsync status=none
sync
GOT=$(sudo head -c "$SIZE" "$DEV" | sha256sum | cut -d' ' -f1)
echo "readback $GOT"
[ "$GOT" = "$WANT" ] && echo FLASH-OK || { echo FLASH-MISMATCH; exit 1; }
