#!/bin/sh
date +%T
M='s/(sip:|tel:)\+?[0-9]{6,}/\1<num>/g; s/[0-9]{10,}/<n>/g'
sudo grep -aE "calls >>>|MO call|MT call|<<< SIP/2.0 (1[0-9][0-9]|[2-6][0-9][0-9])|>>> (INVITE|CANCEL|BYE)|<<< (INVITE|BYE|CANCEL)|hangup|answered|connected|early media|IMS registered|IMS link|not registered|placing the call|dialing over|refused the call|uplink|modem media: (AMR|VoiceMMode)" /var/log/winglm-volte.trace | awk '$1 >= "13:07"' | grep -v "REGISTER from" | tail -50 | sed -E "$M" | cut -c1-140
echo "=== radio / modem"
sudo logread -n 0 | grep -E "Nov 21 13:(0[7-9]|[1-5])" | grep -E "radio-control|state changed \(|rfkill" | cut -c1-160 | tail -10
echo "=== call volume helper"
sudo logread -n 0 | grep -E "winglm-call-volume" | tail -5 | cut -c1-160
