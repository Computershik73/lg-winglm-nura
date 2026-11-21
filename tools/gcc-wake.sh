#!/bin/sh
# wait (<= 10 min) for DSI-1 to be on, then record Phosh's DisplayConfig and
# start Settings under gdb (its window shows on the screen)
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
OUT=/tmp/gcc-wake.txt
echo "wait $(date +%T)" > $OUT
end=$(( $(date +%s) + 600 ))
while [ $(date +%s) -lt $end ]; do
	$E timeout 5 wlr-randr 2>/dev/null | grep -A1 '^DSI-1' | grep -q 'Enabled: yes' && break
	sleep 0.5
done
echo "DSI-1 on $(date +%T)" >> $OUT
sleep 3
$E timeout 5 wlr-randr | grep -E '^[A-Z]|Enabled|Position|Transform' >> $OUT
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.gnome.Mutter.DisplayConfig.GetCurrentState >> $OUT 2>&1
pkill -x gnome-control-c
$E timeout 45 gdb -q -batch -ex 'set pagination off' -ex 'handle SIGPIPE SIG32 SIG33 SIG34 SIG35 nostop noprint pass' \
	-ex run -ex 'echo \n=== STOP ===\n' -ex 'bt 30' --args /usr/bin/gnome-control-center > /tmp/gcc-run-on.txt 2>&1
echo "gdb exit $? $(date +%T)" >> $OUT
