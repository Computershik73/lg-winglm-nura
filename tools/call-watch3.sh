#!/bin/sh
T=/var/log/winglm-volte.trace
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
n0=$(sudo wc -l < $T)
echo "$(date +%T) watching for a call (up to ${1:-900} s)"
end=$(( $(date +%s) + ${1:-900} ))
while [ $(date +%s) -lt $end ]; do
	sudo tail -n +$((n0 + 1)) $T | grep -qE "echo test call|MO call to|MT INVITE" && break
	sleep 1
done
sleep 6
echo "== $(date +%T) during the call"
$E pactl list cards | grep -E "Active Profile"
$E pactl info | grep -E "Default (Sink|Source)"
$E pactl list sink-inputs | grep -E "Sink Input|Sink:|application.name|media.role|Corked|Mute|Volume: (front|mono)|format" | sed 's/^\s*//'
$E pactl list source-outputs | grep -E "Source Output|Source:|application.name|media.role|Corked|Mute|Volume: (front|mono)" | sed 's/^\s*//'
$E pactl list sinks | grep -E "^Sink|Name:|State|Mute|Volume: front" | sed 's/^\s*//'
$E pactl list sources | grep -E "^Source|Name:|State|Mute|Volume: (front|mono)" | sed 's/^\s*//'
S=$($E pactl get-default-sink)
echo "-- 4 s from $S.monitor"
$E timeout 4 parecord -d "$S.monitor" --channels=1 --rate=8000 --format=s16le --file-format=wav /tmp/mon.wav 2>&1 | tail -1
python3 - <<'PY'
import wave, struct
w = wave.open('/tmp/mon.wav'); d = w.readframes(w.getnframes()); w.close()
s = struct.unpack('<%dh' % (len(d) // 2), d)
out = []
for k in range(0, len(s), 4000):
    x = s[k:k + 4000]
    out.append(int((sum(v * v for v in x) / max(1, len(x))) ** 0.5))
print('monitor RMS per 0.5 s:', out)
PY
for i in $(seq 1 600); do
	sudo tail -n +$((n0 + 1)) $T | grep -q "hangup\|MO call failed" && break
	sleep 1
done
sleep 3
echo "== $(date +%T) trace"
sudo tail -n +$((n0 + 1)) $T | grep -v "GNOME Calls REGISTER\|REGISTER sip\|(. REGISTER)\|IPsec\|tcp to"
