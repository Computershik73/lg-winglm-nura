#!/bin/sh
# Temporarily make D-Bus activation start ModemManager with --debug (via a wrapper), capture its QRTR detection, restore
F=/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
printf '#!/bin/sh\nexec /usr/sbin/ModemManager --debug > /tmp/mm.log 2>&1\n' | sudo tee /tmp/mm-debug-wrap.sh >/dev/null
sudo chmod 755 /tmp/mm-debug-wrap.sh
sudo cp $F /tmp/mm-activation.service.orig
sudo sed -i 's#^Exec=/usr/sbin/ModemManager$#Exec=/tmp/mm-debug-wrap.sh#' $F
grep '^Exec' $F
sudo pkill -x ModemManager; sleep 1
mmcli -L >/dev/null 2>&1   # activates it
sleep 50
echo "pid $(pgrep -x ModemManager)"
mmcli -L
sudo cp /tmp/mm-activation.service.orig $F
grep '^Exec' $F
grep -iE "qrtr|qcom-soc|node 0|probing|task|modem" /tmp/mm.log | grep -viE "added server|mtk|rolling|fibocom|could not load|loaded plugin" | head -40 | cut -c1-200
