#!/bin/sh
cd /mnt/android
sudo ls -la system_a/system/system_ext/media/ims | head -30
sudo python3 - <<'EOF'
import zipfile
z = zipfile.ZipFile('system_a/system/system_ext/priv-app/Ims6/Ims6.apk')
names = z.namelist()
print(len(names), 'entries')
for n in names:
    if not n.startswith(('res/', 'META-INF/')) or 'xml/' in n and 'res/xml' in n:
        print(n, z.getinfo(n).file_size)
EOF
# OP partition, read-only
dev=$(readlink -f /dev/disk/by-partlabel/OP_a)
sudo blockdev --setro $dev
sudo mkdir -p /mnt/android/OP_a
mountpoint -q /mnt/android/OP_a || sudo mount -o ro,noload $dev /mnt/android/OP_a 2>&1 | head -2 || sudo mount -o ro $dev /mnt/android/OP_a
echo "OP_a: ro=$(sudo blockdev --getro $dev) $(mountpoint /mnt/android/OP_a)"
sudo find /mnt/android/OP_a -maxdepth 3 | head -50
