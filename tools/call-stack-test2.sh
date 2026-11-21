#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
v() { amixer -c 0 cget "name=$1" | sed -n "s/.*: values=//p" | cut -d, -f1; }
routes() { echo "  routes: EAR=$(v 'RX_EAR Mode') RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-voice=$(v 'PRI_MI2S_RX_Voice Mixer VoiceMMode1') TX3-voice=$(v 'VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1') RX0-MM1=$(v 'RX_CDC_DMA_RX_0 Audio Mixer MultiMedia1') PRI-MM1=$(v 'PRI_MI2S_RX Audio Mixer MultiMedia1')"; }
card() { echo "  $($E pactl list cards 2>/dev/null | grep -E 'Active Profile' | sed 's/^\s*//') / $($E pactl list sinks 2>/dev/null | grep -E 'Active Port' | sed 's/^\s*//')"; }
echo "== call mode"; $E callaudiocli -m 1 2>&1 | tail -1; sleep 2; card; routes
echo "== speaker on"; $E callaudiocli -s 1 2>&1 | tail -1; sleep 2; card; routes
echo "== speaker off"; $E callaudiocli -s 0 2>&1 | tail -1; sleep 2; card; routes
echo "== default mode"; $E callaudiocli -m 0 2>&1 | tail -1; sleep 2; card; routes
echo "== mute test (call mode + active call)"; $E callaudiocli -m 1 2>&1 | tail -1; sleep 2
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:3 int32:4 uint32:0; sleep 2
echo "  voice PCM: $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
$E callaudiocli -u 1 2>&1 | tail -1; sleep 1; echo "  Voice Tx Mute after mute: $(amixer -c 0 cget name='Voice Tx Mute' | sed -n 's/.*: values=//p')"
$E callaudiocli -u 0 2>&1 | tail -1; sleep 1; echo "  Voice Tx Mute after unmute: $(amixer -c 0 cget name='Voice Tx Mute' | sed -n 's/.*: values=//p')"
$E callaudiocli -s 1 2>&1 | tail -1; sleep 2; card; routes; echo "  voice PCM: $(head -1 /proc/asound/card0/pcm2p/sub0/status)"
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0; sleep 1
$E callaudiocli -m 0 2>&1 | tail -1; sleep 2; card; routes
