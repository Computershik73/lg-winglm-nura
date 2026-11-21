dmesg | grep -iE 'Reboot_reason|BootReasonStr|bootreason' | head -4
U=$(readlink -f /dev/disk/by-partlabel/userdata)
L=$(losetup -f); losetup -P -b 4096 "$L" "$U"
mkdir -p /sysroot && mount -o ro "${L}p2" /sysroot && echo MOUNTED
cp /sysroot/var/log/logbookd.db /tmp/logbookd.db && ls -la /tmp/logbookd.db
umount /sysroot && losetup -d "$L" && echo UNMOUNTED
(nc -l -p 9999 < /tmp/logbookd.db &); echo NC-READY
