#!/bin/sh
# Modem bring-up test. EFS: rmtfs works on FILE COPIES of modemst1/modemst2/fsg/fsc;
# the partitions are only read (dd), never opened for writing.
set -e
D=/var/lib/rmtfs
sudo mkdir -p $D
for m in "modemst1 modem_fs1" "modemst2 modem_fs2" "fsg modem_fsg" "fsc modem_fsc"; do
	set -- $m
	if [ ! -s "$D/$2" ]; then
		sudo dd if=/dev/disk/by-partlabel/$1 of=$D/$2 bs=128k status=none
		echo "copied $1 -> $D/$2 ($(stat -c %s $D/$2) bytes)"
	fi
done
sudo sha256sum $D/* | cut -c1-16,65-
U=$(for u in /sys/class/uio/uio*; do [ "$(cat $u/name)" = rmtfs ] && basename $u; done)
[ -e /dev/qcom_rmtfs_uio1 ] || sudo ln -s /dev/$U /dev/qcom_rmtfs_uio1
ls -la /dev/qcom_rmtfs_uio1
pgrep -x rmtfs >/dev/null || { sudo setsid rmtfs -o $D -v > /tmp/rmtfs.log 2>&1 < /dev/null & }
sleep 2
pgrep -a rmtfs; tail -5 /tmp/rmtfs.log
M=$(dmesg | wc -l)
# booting a PIL subsystem on downstream kernels: keep its char device open
pgrep -f 'subsys_modem' >/dev/null || sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 20
echo "== modem state: $(cat /sys/bus/msm_subsys/devices/*/name | paste -d: - /dev/null >/dev/null; for s in /sys/bus/msm_subsys/devices/*; do [ "$(cat $s/name)" = modem ] && cat $s/state; done)"
dmesg | tail -n +$M | grep -viE 'CAM_|healthd|lge_battery|charger|batt|QG-K|SMB1390|PMINFO|TM\]|IDTP|pet_watchdog|UEVENT total' | head -50 | cut -c1-170
echo "== rmtfs"; tail -8 /tmp/rmtfs.log
echo "== net"; ls /sys/class/net
