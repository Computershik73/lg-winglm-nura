#!/bin/sh
# read-only look at Android's system/product (no journal replay, block devices set ro)
for p in system_a product_a; do
	dev=$(readlink -f /dev/mapper/$p)
	sudo blockdev --setro $dev
	sudo mkdir -p /mnt/android/$p
	mountpoint -q /mnt/android/$p || sudo mount -t ext4 -o ro,noload $dev /mnt/android/$p 2>&1 | head -2
	echo "$p: $(blockdev --getro $dev 2>/dev/null) $(mountpoint /mnt/android/$p)"
done
cd /mnt/android
sudo find system_a product_a -iname "*ims*" 2>/dev/null | grep -viE "dims|aims|timsort|images" | head -60
