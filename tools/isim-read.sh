#!/bin/sh
# find the ISIM AID without printing it, then read ISIM identities (masked)
AID=$(sudo qmicli -d qrtr://0 --uim-get-card-status 2>/dev/null | awk '/Application type:.*isim/{f=1} f && /Application ID:/{print $3; exit}' | tr -d "'")
[ -n "$AID" ] || AID=$(sudo qmicli -d qrtr://0 --uim-get-card-status 2>/dev/null | awk '/Application type:.*isim/{f=1} f && /Application ID:/{getline; print $1; exit}' | tr -d "'")
echo "isim aid length: ${#AID}"
echo "$AID" | sed 's/./x/g'
sudo python3 /tmp/uimtool.py read-isim "$AID" 2>&1
