#!/bin/sh
# Stable locally administered WLAN MACs (derived from the SoC serial) in qcacld's wlan_mac.bin format,
# placed in the firmware directory and fed to a pending request through the sysfs fallback
T=/run/msm-firmware-loader/target/wlan/qca_cld
SER=$(cat /sys/devices/soc0/serial_number 2>/dev/null)
H=$(printf 'winglm-wlan-%s' "$SER" | sha256sum | cut -c1-10)
B=$(printf '%02X' $(( (0x${H%????????} & 0xfc) | 0x02 )))   # locally administered, unicast
R=$(echo "$H" | cut -c3-10 | tr a-f A-F)
F=/run/winglm-wlan_mac.bin
for i in 0 1 2 3; do
	last=$(printf '%02X' $(( (0x$(echo $R | cut -c7-8) + i) & 0xff )))
	echo "Intf${i}MacAddress=${B}$(echo $R | cut -c1-6)${last}"
done > $F
echo END >> $F
cat $F
sudo ln -sf $F $T/wlan_mac.bin
L=$(ls -d /sys/class/firmware/*wlan_mac* 2>/dev/null | head -1)
if [ -n "$L" ]; then
	echo "feeding pending request $L"
	echo 1 | sudo tee $L/loading >/dev/null
	sudo sh -c "cat $F > $L/data"
	echo 0 | sudo tee $L/loading >/dev/null
fi
sleep 8
dmesg | tail -100 | grep -iE "mac|wlan0|hdd_|register_netdev|wlan: Loading" | grep -v CAM_ | tail -10 | cut -c1-170
ls /sys/class/net | tr '\n' ' '; echo
ip link show wlan0 2>&1 | head -2
