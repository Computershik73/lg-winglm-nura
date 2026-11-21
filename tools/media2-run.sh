#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
S0=$($E pactl get-default-sink)
$E parec -d "$S0.monitor" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/m2.raw 2>/dev/null &
M=$!
cd /tmp/volte && sudo python3 test_media2.py 2>&1 | grep -v Warning | grep -v "from gi"
kill $M
python3 - <<'PY'
import struct
d = open('/tmp/m2.raw', 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print('speaker monitor RMS per 0.5 s:', [int((sum(v*v for v in s[k:k+4000]) / max(1, len(s[k:k+4000]))) ** 0.5) for k in range(0, len(s), 4000)])
PY
