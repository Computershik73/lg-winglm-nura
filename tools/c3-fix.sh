rm -f /sysroot/etc/runlevels/boot/msm-fb-refresher /sysroot/etc/runlevels/default/msm-fb-refresher /sysroot/etc/runlevels/default/greetd
for r in boot default; do echo "[$r] $(ls /sysroot/etc/runlevels/$r | tr '\n' ' ')"; done
echo "--- logbookd.db header"; head -c 16 /sysroot/var/log/logbookd.db | od -c | head -2
echo "--- /var/log/dmesg (boot it was taken from)"; head -n 2 /sysroot/var/log/dmesg | cut -c1-120; tail -n 3 /sysroot/var/log/dmesg | cut -c1-160
sync
umount /sysroot/boot /sysroot && losetup -d /dev/loop0 && echo UNMOUNTED
