#!/bin/sh
# In the pmbootstrap native chroot: hci_uart.ko (H4 only) for the running linux-lg-winglm r4
set -e
cd /home/pmos/kbt/android_kernel_lge_sm7250-*
export ARCH=arm64 LLVM=1 CC=clang HOSTCC=clang
cp out/.config out/.config.orig
scripts/config --file out/.config -m BT_HCIUART -e BT_HCIUART_H4 -d BT_HCIUART_SERDEV \
	-d BT_HCIUART_NOKIA -d BT_HCIUART_BCSP -d BT_HCIUART_ATH3K -d BT_HCIUART_LL -d BT_HCIUART_3WIRE \
	-d BT_HCIUART_INTEL -d BT_HCIUART_BCM -d BT_HCIUART_QCA -d BT_HCIUART_AG6XX -d BT_HCIUART_MRVL
make O=out olddefconfig > /tmp/olddef.log 2>&1
echo "== config changes vs the running kernel:"
diff out/.config.orig out/.config | grep '^[<>]' | grep -v '^[<>] #' | grep -v '^[<>]$' || true
make O=out -j$(nproc) modules_prepare > /tmp/prep.log 2>&1 || { tail -20 /tmp/prep.log; exit 1; }
cp /home/pmos/kbt/Module.symvers.vmlinux out/Module.symvers
cat out/include/config/kernel.release
make O=out -j$(nproc) M=$PWD/drivers/bluetooth modules > /tmp/mod.log 2>&1 || { tail -30 /tmp/mod.log; exit 1; }
grep -iE "warning|error" /tmp/mod.log | head -10
ls -la drivers/bluetooth/*.ko
modinfo drivers/bluetooth/hci_uart.ko 2>/dev/null | grep -E "vermagic|depends" || strings drivers/bluetooth/hci_uart.ko | grep vermagic
