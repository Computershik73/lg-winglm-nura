#!/bin/sh
# boot-like cycles: winglm-bt and bluetooth started together; result per cycle
for i in 1 2 3; do
	sudo rc-service bluetooth stop >/dev/null 2>&1; sudo rc-service winglm-bt stop >/dev/null 2>&1; sleep 2
	sudo rc-service winglm-bt start >/dev/null 2>&1; sudo rc-service bluetooth start >/dev/null 2>&1
	sleep 14
	p=$(bluetoothctl show | grep -o "Powered: ..*")
	n=$(timeout 10 bluetoothctl --timeout 7 scan on 2>/dev/null | grep -c "Device")
	echo "cycle $i: $p, devices $n, $(hciconfig hci0 | grep -o 'RX bytes:[0-9]*'), timeouts so far $(dmesg | grep -c 'tx timeout')"
done
echo "toggle like the shell's switch:"
sudo python3 /tmp/rfkill-all.py block; sleep 4
echo "  off: $(for r in /sys/class/rfkill/*; do printf '%s=%s ' $(cat $r/name) $(cat $r/soft); done)"
sudo python3 /tmp/rfkill-all.py unblock; sleep 16
p=$(bluetoothctl show | grep -o "Powered: ..*")
n=$(timeout 10 bluetoothctl --timeout 7 scan on 2>/dev/null | grep -c "Device")
echo "  on: $p, devices $n, timeouts so far $(dmesg | grep -c 'tx timeout')"
