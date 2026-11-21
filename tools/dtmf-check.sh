#!/bin/sh
date +%T
L=/var/log/winglm-volte.trace
sudo grep -anE "calls >>> (INVITE|INFO|BYE)|DTMF|INFO from Calls|modem media:|call (ended|connected)|hangup|MO call|MT call|>>> INVITE|<<< SIP/2.0 (18|200 OK \([0-9]+ INVITE)" $L | awk -F: '$1>0' | tail -60 | cut -d: -f2- | cut -c1-140 | sed -E 's/(sip:|tel:)\+?[0-9]{6,}/\1<num>/g; s/[0-9]{10,}/<n>/g'
echo --- voice
tail -n 15 /var/log/winglm-voice.log 2>/dev/null | cut -c1-120
echo --- mute
grep -aiE "mute" /var/log/messages 2>/dev/null | tail -8 | cut -c1-140
