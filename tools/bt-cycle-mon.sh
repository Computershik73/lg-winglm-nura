#!/bin/sh
# One stop/start cycle of winglm-bt with btmon recording; then summarize what the controller sent
sudo rc-service bluetooth stop >/dev/null 2>&1
sudo rc-service winglm-bt stop >/dev/null 2>&1; sleep 2
sudo sh -c "btmon -w /tmp/bt.snoop > /dev/null 2>&1 &"; sleep 1
sudo rc-service winglm-bt start >/dev/null 2>&1; sleep 9
sudo btmgmt --index 0 power on 2>&1 | tail -1; sleep 2
sudo pkill -x btmon; sleep 1
hciconfig hci0 | grep -E "bytes"
sudo btmon -r /tmp/bt.snoop 2>/dev/null | grep -E "^[<>@=]|Diagnostic|Vendor|Hardware Error|Status" | head -60 | cut -c1-120
