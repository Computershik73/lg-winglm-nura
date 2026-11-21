#!/bin/sh
# Voice Call verb through alsaucm: earpiece + mic, voice PCMs open, switch to speaker and back mid-session
U=/usr/share/alsa/ucm2/conf.d/lito-mtp-snd-ca
sudo cp /tmp/ucm/lito-mtp-snd-card.conf /tmp/ucm/VoiceCall.conf $U/
alsaucm -c hw:0 list _verbs 2>&1 | grep -E "HiFi|Voice"
N0=$(dmesg | wc -l)
alsaucm -c hw:0 set _verb "Voice Call" set _enadev Earpiece set _enadev Mic &
U1=$!; sleep 1.5
python3 /tmp/voice-open.py hw:0,2 14 > /tmp/vo.log 2>&1 &
V=$!; sleep 3
amixer -c 0 cget "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" | grep ": values"
echo "-> speaker"; alsaucm -c hw:0 set _verb "Voice Call" set _disdev Earpiece set _enadev Speaker; sleep 3
echo "   PRI voice: $(amixer -c 0 cget 'name=PRI_MI2S_RX_Voice Mixer VoiceMMode1' | grep -o 'values=.*') RX0 voice: $(amixer -c 0 cget 'name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1' | grep -o 'values=.*')"
echo "-> earpiece"; alsaucm -c hw:0 set _verb "Voice Call" set _disdev Speaker set _enadev Earpiece; sleep 3
wait $V; cat /tmp/vo.log
dmesg | tail -n +$N0 | grep -viE "deregister|Cal block is NULL|Unmap VOC|EALREADY|returned error = 0x9|afe_close" | grep -iE "voice|voc_|mvm|cvs|cvp|dpcm|asoc|error|fail" | head -15 | cut -c1-170
alsaucm -c hw:0 set _verb HiFi
echo "after HiFi: EAR $(amixer -c 0 cget 'name=RX_EAR Mode' | grep -o 'values=.*') voice-mixer $(amixer -c 0 cget 'name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1' | grep -o 'values=.*')"
