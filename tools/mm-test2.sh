#!/bin/sh
sudo rc-service modemmanager stop >/dev/null 2>&1
sudo rc-service modemmanager zap >/dev/null 2>&1
for i in 1 2 3; do sudo pkill -x ModemManager; sleep 1; done
pgrep -a ModemManager
cat /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service 2>/dev/null | grep -E 'Exec|SystemdService'
sudo setsid ModemManager --debug > /tmp/mm.log 2>&1 < /dev/null &
sleep 60
ps -o pid,etime,args | grep '[M]odemManager'
mmcli -L 2>&1
grep -iE 'qcom-soc|probing|created|exported|state changed|unlock|sim |registration|net port|rmnet|ipa|bearer|qrtr0|power|reason' /tmp/mm.log | grep -viE 'mtk|rolling|fibocom|could not load|added server|loaded plugin' | head -40 | cut -c1-190
tail -5 /tmp/mm.log | cut -c1-190
