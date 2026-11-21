#!/bin/sh
# modem media loopback with the AP voice path (VoiceMMode1) enabled
CPID=$(pgrep -u $(id -u) -x callaudiod | head -1)
export $(tr '\0' '\n' < /proc/$CPID/environ | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=')
echo "bus: $DBUS_SESSION_BUS_ADDRESS"
CA="gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
$CA 1 >/dev/null 2>&1; echo "callaudiod mode 1: $?"
sleep 1
python3 /tmp/volte/voice-open.py hw:0,2 22 > /tmp/voice-open.out 2>&1 &
VP=$!
sleep 1
sh /tmp/volte/mmpf-diag.sh "mmpfprobe2.py 12" 22 0 > /dev/null
wait $VP
cat /tmp/voice-open.out
$CA 0 >/dev/null 2>&1; echo "callaudiod mode 0: $?"
cat /tmp/mmpf-probe.out
sh /tmp/volte/mmpf-grep.sh "NumReceived|dss_sendto|SendTo|VoiceSource|Uplink|Dnlink|ProcessUplinkData|ProcessDnlinkData|vocoder|VS_VOC|Enable|CVD|jitter|Error|fail" 80
