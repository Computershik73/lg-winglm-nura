#!/bin/sh
sudo rc-service modemmanager stop >/dev/null 2>&1
sudo pkill -x ModemManager; sleep 2
pgrep -a ModemManager
sudo setsid ModemManager --debug > /tmp/mm.log 2>&1 < /dev/null &
sleep 40
mmcli -L 2>&1
M=$(mmcli -L 2>/dev/null | grep -oE '/Modem/[0-9]+' | head -1 | grep -oE '[0-9]+$')
if [ -n "$M" ]; then
	mmcli -m $M 2>&1 | grep -viE 'imei|equipment id|own numbers|^\s*$' | head -50
	mmcli -m $M --signal-get 2>&1 | head -5
fi
grep -iE 'qrtr|qcom-soc|port probe|new modem|net port|rmnet|ipa|error|failed' /tmp/mm.log | grep -viE 'mtk|rolling|fibocom|could not load' | head -30 | cut -c1-180
