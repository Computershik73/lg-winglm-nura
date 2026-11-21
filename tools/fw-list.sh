#!/bin/sh
# Mount the NON-HLOS (modem_a) and DSP partitions READ-ONLY and list firmware; nothing is written to them
set -e
for p in modem_a dsp_a bluetooth_a; do
	d=/dev/disk/by-partlabel/$p
	[ -e $d ] || { echo "no $p"; continue; }
	echo "== $p: $(blkid -o export $d 2>/dev/null | grep -E '^(TYPE|LABEL)=' | tr '\n' ' ') size $(blockdev --getsize64 $d)"
	m=/mnt/ro-$p
	mkdir -p $m
	mountpoint -q $m || mount -o ro,noexec,nodev,nosuid $d $m
	echo "mount: $(grep " $m " /proc/mounts | awk '{print $4}' | cut -d, -f1)"
done
ls /mnt/ro-modem_a/image | tr '\n' ' ' | fold -w 200; echo
ls /mnt/ro-bluetooth_a/image 2>/dev/null | tr '\n' ' '; echo
ls /mnt/ro-dsp_a 2>/dev/null | head;
ls /sys/class/uio 2>/dev/null && for u in /sys/class/uio/*; do echo "$u: $(cat $u/name)"; done
ls /dev/subsys_* 2>/dev/null
cat /sys/kernel/boot_adsp/* 2>/dev/null | head -3; ls /sys/kernel/boot_adsp
