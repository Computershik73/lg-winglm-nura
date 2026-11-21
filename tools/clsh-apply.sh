#!/bin/sh
# earpiece Class-H mode: live + UCM files (test deploy, packaged in r31)
U=/usr/share/alsa/ucm2/conf.d/lito-mtp-snd-ca
sudo cp /tmp/volte/HiFi.conf /tmp/volte/VoiceCall.conf $U/
sudo amixer -c 0 cset name='RX_HPH_PWR_MODE' ULP >/dev/null
sudo amixer -c 0 cset name='RX HPH Mode' CLS_H_ULP >/dev/null
for c in 'RX HPH Mode' 'RX_HPH_PWR_MODE' 'EAR PA GAIN'; do
	printf '%-16s %s\n' "$c" "$(amixer -c 0 cget name="$c" | sed -n 's/.*: values=//p')"
done
grep -c CLS_H_ULP $U/VoiceCall.conf $U/HiFi.conf
dmesg | grep -i "hph mode\|clsh" | tail -3
