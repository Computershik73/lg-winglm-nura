#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
n0=$(sudo wc -l < /var/log/winglm-volte.trace)
python3 /tmp/volte/callprobe.py 0000000 8 > /tmp/probe.out 2>&1 &
sleep 3
$E pactl list cards | grep "Active Profile"
S=$($E pactl get-default-sink)
echo "sink: $S"
$E pactl list short sink-inputs
$E timeout 3 parec -d "$S.monitor" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/m3.raw 2>/dev/null
python3 - <<'PY'
import struct
d = open('/tmp/m3.raw', 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print('monitor RMS per 0.25 s:', [int((sum(v*v for v in s[k:k+2000]) / max(1, len(s[k:k+2000]))) ** 0.5) for k in range(0, len(s), 2000)])
PY
wait
sleep 2
$E pactl list cards | grep "Active Profile"
sudo tail -n +$((n0 + 1)) /var/log/winglm-volte.trace | grep -v "GNOME Calls REGISTER\|lvl_mic"
