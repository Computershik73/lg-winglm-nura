#!/bin/sh
sudo pkill -x grep 2>/dev/null
cd /mnt/android
sudo find system_a product_a \( -iname "*ims*" -o -iname "*volte*" -o -iname "*mmpf*" \) \( -name "*.xml" -o -name "*.db" -o -name "*.conf" -o -name "*.cfg" -o -name "*.json" -o -name "*.apk" -o -type d \) 2>/dev/null | grep -viE "images|dims|aims|claims|anims|sims/|timsort" | head -60
echo ---
ls /dev/mapper/ 2>/dev/null | head -40
ls -la /dev/disk/by-partlabel/ 2>/dev/null | grep -iE "op|carrier|product|odm|vendor" | head
