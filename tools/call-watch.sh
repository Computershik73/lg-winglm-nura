#!/bin/sh
# wait for a VoLTE call in the daemon trace, then snapshot the audio path
T=/var/log/winglm-volte.trace
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
n0=$(sudo wc -l < $T)
echo "$(date +%T) watching for a call (up to ${1:-900} s)"
end=$(( $(date +%s) + ${1:-900} ))
while [ $(date +%s) -lt $end ]; do
	if sudo tail -n +$((n0 + 1)) $T | grep -qE "MO call to|MT INVITE"; then break; fi
	if mmcli -m any --voice-list-calls 2>/dev/null | grep -q "/Call/"; then echo "$(date +%T) CS call (modem) seen"; break; fi
	sleep 1
done
sleep 7
echo "== $(date +%T) during the call"
sudo tail -n +$((n0 + 1)) $T | grep -v "GNOME Calls REGISTER"
echo "-- card profile / default sink+source"
$E pactl list cards | grep -E "Active Profile"
$E pactl info | grep -E "Default (Sink|Source)"
echo "-- streams"
$E pactl list sink-inputs | grep -E "Sink Input|Sink:|application.name|media.role|Mute|Volume: front" | sed 's/^\s*//'
$E pactl list source-outputs | grep -E "Source Output|Source:|application.name|media.role|Mute" | sed 's/^\s*//'
$E pactl list sinks | grep -E "^Sink|Name:|Active Port|State" | sed 's/^\s*//'
echo "-- mixer"
for c in "RX_CDC_DMA_RX_0 Audio Mixer MultiMedia1" "PRI_MI2S_RX Audio Mixer MultiMedia1" "EAR_RDAC Switch" "RX_EAR Mode" "MultiMedia2 Mixer TX_CDC_DMA_TX_3" "RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1"; do
	printf '%s: %s\n' "$c" "$(amixer -c 0 cget "name=$c" 2>/dev/null | grep -o ': values=.*')"
done
head -1 /proc/asound/card0/pcm0p/sub0/status; head -1 /proc/asound/card0/pcm1c/sub0/status
echo "callaudiod: $($E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.freedesktop.DBus.Properties.Get org.mobian_project.CallAudio AudioMode 2>&1)"
# wait for the end
for i in $(seq 1 600); do
	sudo tail -n +$((n0 + 1)) $T | grep -q "hangup\|MO call failed\|torn down" && break
	sleep 1
done
sleep 2
echo "== $(date +%T) after the call"
sudo tail -n +$((n0 + 1)) $T | grep -v "GNOME Calls REGISTER" | tail -12
