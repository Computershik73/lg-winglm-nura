U=$(readlink -f /dev/disk/by-partlabel/userdata)
L=$(losetup -f); losetup -P -b 4096 "$L" "$U"
mkdir -p /sysroot && mount "${L}p2" /sysroot && echo MOUNTED
mkdir -p /sysroot/etc/elogind/logind.conf.d /sysroot/etc/elogind/sleep.conf.d /sysroot/etc/NetworkManager/conf.d
printf '[Login]\n# LG Wing port: a short press powered the phone off and the display\n# hang on shutdown then tripped the watchdog\nHandlePowerKey=ignore\nHandlePowerKeyLongPress=ignore\n' > /sysroot/etc/elogind/logind.conf.d/50-winglm.conf
printf '[Sleep]\n# suspend is not working on the downstream kernel yet\nAllowSuspend=no\nAllowHibernation=no\nAllowHybridSleep=no\nAllowSuspendThenHibernate=no\n' > /sysroot/etc/elogind/sleep.conf.d/50-winglm.conf
printf '[keyfile]\n# USB networking is set up by the initramfs/unudhcpd, keep NM off it\nunmanaged-devices=interface-name:usb0\n' > /sysroot/etc/NetworkManager/conf.d/50-winglm-usb0.conf
for f in /sysroot/etc/elogind/logind.conf.d/50-winglm.conf /sysroot/etc/elogind/sleep.conf.d/50-winglm.conf /sysroot/etc/NetworkManager/conf.d/50-winglm-usb0.conf; do echo "== $f"; grep -v '^#' "$f"; done
sync; umount /sysroot && losetup -d "$L" && echo UNMOUNTED
touch /tmp/continue_boot && echo CONTINUING
