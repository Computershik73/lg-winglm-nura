#!/bin/sh
# New UCM (no conflicts), PA restarted; callaudiod CALL mode -> fake active call (q6voiced service) -> speaker on/off -> end
U=/usr/share/alsa/ucm2/conf.d/lito-mtp-snd-ca
sudo cp /tmp/ucm/VoiceCall.conf /tmp/ucm/HiFi.conf $U/
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E pulseaudio -k 2>/dev/null; sleep 2; $E pulseaudio --start 2>/dev/null; sleep 5
v() { amixer -c 0 cget "name=$1" | sed -n "s/.*: values=//p" | cut -d, -f1; }
routes() { echo "  routes: EAR=$(v 'RX_EAR Mode') RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-voice=$(v 'PRI_MI2S_RX_Voice Mixer VoiceMMode1') TX3-voice=$(v 'VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1') RX0-MM1=$(v 'RX_CDC_DMA_RX_0 Audio Mixer MultiMedia1') PRI-MM1=$(v 'PRI_MI2S_RX Audio Mixer MultiMedia1')"; }
card() { echo "  $($E pactl list cards 2>/dev/null | grep -E 'Active Profile' | sed 's/^\s*//') / $($E pactl list sinks 2>/dev/null | grep -E 'Active Port' | sed 's/^\s*//')"; }
pcm2() { echo "  voice PCM: play=$(head -1 /proc/asound/card0/pcm2p/sub0/status) capt=$(head -1 /proc/asound/card0/pcm2c/sub0/status)"; }
sig() { sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:$1 int32:$2 uint32:0; }
echo "== profiles: $($E pactl list cards | sed -n '/Profiles:/,/Active Profile/p' | grep -cE '^\s+(HiFi|Voice Call)')"; $E pactl list cards | sed -n '/Profiles:/,/Active Profile/p' | grep -E "^\s+(HiFi|Voice)" | cut -c1-70
$E pactl list sinks | sed -n '/Ports:/,/Active Port/p' | cut -c1-80
echo "== call mode"; $E callaudiocli -m 1 2>&1 | tail -1; sleep 2; card; routes
N0=$(dmesg | wc -l)
echo "== call active"; sig 3 4; sleep 2; pcm2
echo "== speaker on"; $E callaudiocli -s 1 2>&1 | tail -1; sleep 2; card; routes; pcm2
echo "== speaker off"; $E callaudiocli -s 0 2>&1 | tail -1; sleep 2; card; routes; pcm2
echo "== call ended"; sig 4 7; sleep 2; pcm2
echo "== default mode"; $E callaudiocli -m 0 2>&1 | tail -1; sleep 2; card; routes
dmesg | tail -n +$N0 | grep -viE "deregister|Cal block is NULL|Unmap VOC|EALREADY|returned error = 0x[9a]|afe_close|No cal data|Voice_get_cal|tfa" | grep -iE "voice|voc_|dpcm|asoc|error|fail" | head -8 | cut -c1-160
