#!/bin/sh
# full downlink path with a clean tone, in call mode; count gaps in the sink monitor
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --timeout 15 --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
$CA 1 >/dev/null; sleep 2
S=$($E pactl get-default-sink)
cd /tmp/volte
sudo python3 test_media2.py > /tmp/tm2.out 2>&1 &
sleep 1.5
$E timeout 4 parec -d "$S.monitor" --raw --channels=1 --rate=48000 --format=s16le --latency-msec=20 > /tmp/g.raw 2>/dev/null
wait
$CA 0 >/dev/null
grep -E "packets|level" /tmp/tm2.out | tail -3
python3 - <<'PY'
import struct
d = open('/tmp/g.raw', 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
# gaps: runs of >= 2 ms (96 samples) of near-zero inside the tone
runs, cur = [], 0
for v in s:
    if abs(v) < 30:
        cur += 1
    else:
        if cur >= 96:
            runs.append(cur)
        cur = 0
peak = max(abs(v) for v in s) if s else 0
# discontinuities: big sample-to-sample jumps relative to a 600 Hz sine at 48 kHz
jumps = sum(1 for a, b in zip(s, s[1:]) if abs(b - a) > max(2000, peak * 0.2))
print('captured %.2f s, peak %d, silent gaps >=2 ms: %d (longest %.1f ms), sample jumps: %d'
      % (len(s) / 48000.0, peak, len(runs), (max(runs) / 48.0) if runs else 0, jumps))
PY
