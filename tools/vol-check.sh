#!/bin/sh
amixer -c 0 scontrols | grep -iE "RX_RX0 Digital|RX_RX1 Digital|EAR|HPH|TX_DEC0|ADC1 |TFA|SPK" | head
for c in "RX_RX0 Digital Volume" "RX_RX1 Digital Volume" "TX_DEC0 Volume" "ADC1 Volume"; do echo "$c: $(amixer -c 0 cget "name=$c" | grep -E 'type=|: values=' | tr -s ' ' | tr '\n' ' ')"; done
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
amixer -c 0 -q cset "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 0
$E callaudiocli -m 1 >/dev/null 2>&1; sleep 2
for st in "0 1" "1 2"; do set -- $st
	sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/2 org.freedesktop.ModemManager1.Call.StateChanged int32:$1 int32:$2 uint32:0; sleep 1.5
	echo "state $1 -> $2: voice PCM $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
done
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/2 org.freedesktop.ModemManager1.Call.StateChanged int32:2 int32:7 uint32:0; sleep 1
echo "ended: $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
$E callaudiocli -m 0 >/dev/null 2>&1
