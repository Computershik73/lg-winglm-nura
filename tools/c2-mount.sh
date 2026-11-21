U=$(readlink -f /dev/disk/by-partlabel/userdata); echo "userdata=$U"
L=$(losetup -f); losetup -P -b 4096 "$L" "$U" 2>&1 || losetup -b 4096 "$L" "$U"
echo "loop=$L"; partx -a "$L" 2>/dev/null; ls ${L}*
blkid ${L}p1 ${L}p2
mkdir -p /sysroot && mount ${L}p2 /sysroot && mount ${L}p1 /sysroot/boot && echo MOUNTED
for r in sysinit boot default; do echo "[$r] $(ls /sysroot/etc/runlevels/$r | tr '\n' ' ')"; done
echo "--- logs"; ls -lt /sysroot/var/log | head -12
