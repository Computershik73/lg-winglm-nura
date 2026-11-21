U=$(readlink -f /dev/disk/by-partlabel/userdata)
L=$(losetup -f); losetup -P -b 4096 "$L" "$U"
mkdir -p /sysroot && mount "${L}p2" /sysroot && echo MOUNTED
mkdir -p /sysroot/etc/runlevels/winglm-off
for s in apk-polkit-server bluetooth call_audio_idle_suspend_workaround elogind iio-sensor-proxy modemmanager openrc-settingsd seatd usb-signaller; do
	[ -e "/sysroot/etc/runlevels/default/$s" ] && mv "/sysroot/etc/runlevels/default/$s" /sysroot/etc/runlevels/winglm-off/
done
echo "[default] $(ls /sysroot/etc/runlevels/default | tr '\n' ' ')"
echo "[winglm-off] $(ls /sysroot/etc/runlevels/winglm-off | tr '\n' ' ')"
cp /sysroot/var/log/logbookd.db /tmp/logbookd.db && ls -la /tmp/logbookd.db
sync; umount /sysroot && losetup -d "$L" && echo UNMOUNTED
(nc -l -p 9999 < /tmp/logbookd.db &) ; echo NC-READY
