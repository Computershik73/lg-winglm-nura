#!/bin/sh
# Map the dynamic partitions in super and mount vendor_a READ-ONLY where msm-firmware-loader
# would (it does this itself on the next boot now that make-dynpart-mappings is installed)
set -e
B=/run/msm-firmware-loader
SUPER=$(readlink -f /dev/disk/by-partlabel/super)
echo "super: $SUPER"
[ -e /dev/mapper/vendor_a ] || sudo make-dynpart-mappings "$SUPER"
ls /dev/mapper | tr '\n' ' '; echo
sudo mkdir -p $B/mnt/vendor_a
mountpoint -q $B/mnt/vendor_a || sudo mount -o ro,nodev,noexec,nosuid /dev/mapper/vendor_a $B/mnt/vendor_a
grep " $B/mnt/vendor_a " /proc/mounts | awk '{print $1, $4}'
# link vendor firmware like msm-firmware-loader does (skip names already present)
n=0
for blob in $B/mnt/vendor_a/firmware/*; do
	b=$(basename "$blob")
	[ -e "$B/target/$b" ] || [ -L "$B/target/$b" ] && continue
	sudo ln -s "$blob" "$B/target/$b"; n=$((n+1))
done
echo "linked $n vendor firmware entries"
ls -la $B/target/tfa98xx.cnt $B/target/crbtfw32.tlv $B/target/crnv32.bin 2>&1 | awk '{print $9, $10, $11}'
