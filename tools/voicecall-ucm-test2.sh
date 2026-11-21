#!/bin/sh
# One alsaucm process (batch from a pipe): Voice Call verb, earpiece -> speaker -> earpiece -> HiFi with the voice PCMs open
PROFILE=${1:-music}
v() { amixer -c 0 cget "name=$1" | sed -n 's/.*: values=//p'; }
amixer -c 0 -q cset "name=SPK Profile" "$PROFILE"
N0=$(dmesg | wc -l)
(
	echo 'set _verb "Voice Call"'; echo "set _enadev Earpiece"; echo "set _enadev Mic"; sleep 1.5
	python3 /tmp/voice-open.py hw:0,2 12 > /tmp/vo.log 2>&1 &
	sleep 3
	echo "EAR route: RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-voice=$(v 'PRI_MI2S_RX_Voice Mixer VoiceMMode1')" >&2
	echo "set _disdev Earpiece"; echo "set _enadev Speaker"; sleep 3
	echo "SPK route: RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-voice=$(v 'PRI_MI2S_RX_Voice Mixer VoiceMMode1') tfa=$(sudo cat /sys/kernel/debug/tfa98xx-34/fw-state 2>/dev/null)" >&2
	echo "set _disdev Speaker"; echo "set _enadev Earpiece"; sleep 2
	echo "EAR again: RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-voice=$(v 'PRI_MI2S_RX_Voice Mixer VoiceMMode1')" >&2
	sleep 5
	echo 'set _verb HiFi'; sleep 1
	echo "HiFi: EAR=$(v 'RX_EAR Mode') RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-MM1=$(v 'PRI_MI2S_RX Audio Mixer MultiMedia1')" >&2
	echo 'reset'
) | alsaucm -c hw:0 -b - 2>&1 | grep -v "^$"
cat /tmp/vo.log | tr '\n' ' '; echo
dmesg | tail -n +$N0 | grep -viE "deregister|Cal block is NULL|Unmap VOC|EALREADY|returned error = 0x[9a]|afe_close|No cal data|Voice_get_cal" | grep -iE "tfa|voice|voc_|dpcm|asoc|error|fail" | sort | uniq -c | head -12 | cut -c1-160
amixer -c 0 -q cset "name=SPK Profile" music
