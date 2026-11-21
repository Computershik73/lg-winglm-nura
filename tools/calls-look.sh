#!/bin/sh
date +%T
M='s/(sip:|tel:)\+?[0-9]{6,}/\1<num>/g; s/[0-9]{10,}/<n>/g; s/\+7[0-9]{10}/<num>/g'
echo "=== volte trace (calls)"
sudo grep -aE "calls >>>|MO call|MT call|<<< SIP/2.0 (1[0-9][0-9]|[2-6][0-9][0-9])|>>> (INVITE|CANCEL|BYE|PRACK|UPDATE|ACK)|<<< (INVITE|BYE|UPDATE|CANCEL)|hangup|answered|connected|modem media: (AMR|response|DTMF|VoiceMMode)|early|ringback|uplink|GNOME Calls REGISTER|IMS registered|start failed" /var/log/winglm-volte.trace | awk '$1 >= "12:5"' | tail -70 | sed -E "$M" | cut -c1-150
echo "=== winglm-voice"
tail -n 25 /var/log/winglm-voice.log | cut -c1-120
