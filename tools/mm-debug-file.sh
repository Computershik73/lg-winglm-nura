#!/bin/sh
F=/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
RELOAD="dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig"
sudo cp $F /tmp/mm-dbus.service.bak
sudo sed -i 's|^Exec=/usr/sbin/ModemManager$|Exec=/usr/sbin/ModemManager --test-quick-suspend-resume --log-level=DEBUG --log-file=/tmp/mm.log|' $F
sudo $RELOAD >/dev/null; sleep 1
sudo rm -f /tmp/mm.log
sudo pkill -x ModemManager; sleep 1
mmcli -L >/dev/null 2>&1
for i in $(seq 1 40); do mmcli -m any 2>/dev/null | grep -q "state: registered" && break; sleep 2; done
sudo cp /tmp/mm-dbus.service.bak $F; sudo $RELOAD >/dev/null
ps -o pid,args | grep "[M]odemManager"
sudo grep -iE "data format|aggregation|kernel data mode|multiplex|downstream|link layer|net driver|preallocated" /tmp/mm.log | grep -vE "<<<<<<|identifier" | sed -E "s/[0-9]{12,}/<n>/g" | head -30 | cut -c1-200
