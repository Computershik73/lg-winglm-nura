#!/bin/sh
# q6voiced in the foreground; fake ModemManager call signals; voice PCM state
sudo rc-service q6voiced stop >/dev/null 2>&1
sudo sh -c "setsid python3 -c 'import os,grp,pwd; os.setgroups([]); os.setgid(grp.getgrnam(\"audio\").gr_gid); os.setuid(pwd.getpwnam(\"nobody\").pw_uid); os.execvp(\"q6voiced\", [\"q6voiced\", \"hw:0,2\"])' > /tmp/q6v.log 2>&1 < /dev/null &"
sleep 1; pgrep -a q6voiced
pcm2() { echo "  voice PCM: play=$(head -1 /proc/asound/card0/pcm2p/sub0/status) capt=$(head -1 /proc/asound/card0/pcm2c/sub0/status)"; }
# routes the voice front end needs (as the Voice Call verb sets them)
amixer -c 0 -q cset "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 1
amixer -c 0 -q cset "name=VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" 1
for st in "0 3" "3 4"; do
	set -- $st
	sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:$1 int32:$2 uint32:0
	sleep 1.5; echo "state $1 -> $2:"; pcm2
done
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0
sleep 1.5; echo "state 4 -> 7:"; pcm2
cat /tmp/q6v.log
amixer -c 0 -q cset "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 0
amixer -c 0 -q cset "name=VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" 0
sudo pkill -x q6voiced; sudo rc-service q6voiced start >/dev/null 2>&1
