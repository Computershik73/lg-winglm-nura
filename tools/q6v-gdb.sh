#!/bin/sh
sudo rc-service q6voiced stop >/dev/null 2>&1; sudo pkill -x q6voiced
cat > /tmp/q6v.gdb <<'G'
set pagination off
set breakpoint pending on
break snd_pcm_set_params
commands
silent
printf "set_params(pcm=%p, format=%d, access=%d, channels=%u, rate=%u, soft_resample=%d, latency=%u)\n", $x0, $x1, $x2, $x3, $x4, $x5, $x6
continue
end
run
G
sudo sh -c "setsid gdb -q -batch -x /tmp/q6v.gdb --args q6voiced hw:0,2 > /tmp/q6v-gdb.log 2>&1 < /dev/null &"
sleep 3
amixer -c 0 -q cset "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 1
amixer -c 0 -q cset "name=VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" 1
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:3 int32:4 uint32:0
sleep 2
sudo dbus-send --system --type=signal /org/freedesktop/ModemManager1/Call/1 org.freedesktop.ModemManager1.Call.StateChanged int32:4 int32:7 uint32:0
sleep 1
grep -E "set_params|Failed|PCM|error" /tmp/q6v-gdb.log | head
sudo pkill -x gdb; sudo pkill -x q6voiced
amixer -c 0 -q cset "name=RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 0
amixer -c 0 -q cset "name=VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" 0
sudo rc-service q6voiced start >/dev/null 2>&1
