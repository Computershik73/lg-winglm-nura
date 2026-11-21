#!/bin/sh
# One-shot test session; callaudiod CALL mode, fake ModemManager call signals for q6voiced, speaker on/off
C=/etc/phrog/greetd-config.toml
printf '#!/bin/sh\nexec /usr/bin/phosh-session > /tmp/sess.log 2>&1\n' | sudo tee /usr/local/bin/winglm-logged-session >/dev/null; sudo chmod 755 /usr/local/bin/winglm-logged-session
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
OLD=$(pgrep -n -u user -x phosh); sudo rm -f /run/greetd.run; sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 60); do N=$(pgrep -n -u user -x phosh); [ -n "$N" ] && [ "$N" != "$OLD" ] && break; sleep 0.5; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
PP=$(pgrep -n -u user -x phosh); echo "session phosh $PP, autologin lines $(grep -c '^\[initial_session\]' $C)"
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep 12
v() { amixer -c 0 cget "name=$1" | sed -n "s/.*: values=//p" | cut -d, -f1; }
routes() { echo "  routes: EAR=$(v 'RX_EAR Mode') RX0-voice=$(v 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') PRI-voice=$(v 'PRI_MI2S_RX_Voice Mixer VoiceMMode1') TX3-voice=$(v 'VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1') RX0-MM1=$(v 'RX_CDC_DMA_RX_0 Audio Mixer MultiMedia1') PRI-MM1=$(v 'PRI_MI2S_RX Audio Mixer MultiMedia1')"; }
card() { $E pactl list cards 2>/dev/null | grep -E "Active Profile"; $E pactl list sinks 2>/dev/null | grep -E "Active Port"; }
pcm2() { echo "  voice PCM: play=$(cat /proc/asound/card0/pcm2p/sub0/status 2>/dev/null | sed -n 's/^state: //p;/closed/p' | head -1) capt=$(cat /proc/asound/card0/pcm2c/sub0/status 2>/dev/null | sed -n 's/^state: //p;/closed/p' | head -1)"; }
sig() { sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/0 org.freedesktop.ModemManager1.Call.StateChanged int32:$1 int32:$2 uint32:0; }
echo "== profiles"; $E pactl list cards 2>/dev/null | sed -n '/Profiles:/,/Active Profile/p' | grep -E "HiFi|Voice|Active" | cut -c1-100
echo "== call mode"; $E callaudiocli -m 1 2>&1 | tail -1; sleep 2; card; routes
echo "== call active (fake MM signal)"; sig 2 4; sleep 2; pcm2
echo "== speaker on"; $E callaudiocli -s 1 2>&1 | tail -1; sleep 2; card; routes; pcm2
echo "== speaker off"; $E callaudiocli -s 0 2>&1 | tail -1; sleep 2; card; routes; pcm2
echo "== call ended"; sig 4 7; sleep 2; pcm2
echo "== default mode"; $E callaudiocli -m 0 2>&1 | tail -1; sleep 2; card; routes
sudo tail -5 /var/log/messages 2>/dev/null | grep -i q6voice
