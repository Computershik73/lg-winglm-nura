#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
CA="$E gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
RX='udpsrc port=5004 caps="application/x-rtp,media=audio,clock-rate=8000,encoding-name=PCMA,payload=8"'
$CA 1 >/dev/null; sleep 2
$E gst-launch-1.0 -q audiotestsrc is-live=true freq=700 volume=0.2 ! audio/x-raw,rate=8000,channels=1 ! alawenc ! rtppcmapay ! udpsink host=127.0.0.1 port=5004 > /dev/null 2>&1 &
S=$!
S0=$($E pactl get-default-sink)
for variant in plain duplex; do
	if [ $variant = plain ]; then
		P="$RX ! rtpjitterbuffer ! rtppcmadepay ! alawdec ! audioconvert ! audioresample ! pulsesink name=audiosink"
	else
		P="$RX ! rtpjitterbuffer ! rtppcmadepay ! alawdec ! audioconvert ! audioresample ! pulsesink name=audiosink pulsesrc name=audiosource ! audioconvert ! audioresample ! audio/x-raw,rate=8000,channels=1 ! alawenc ! rtppcmapay ! udpsink host=127.0.0.1 port=5010"
	fi
	$E parec -d "$S0.monitor" --raw --channels=1 --rate=8000 --format=s16le --latency-msec=20 > /tmp/m.raw 2>/dev/null &
	M=$!
	$E GST_DEBUG=2 timeout 5 gst-launch-1.0 -q $P > /tmp/gst-$variant.log 2>&1
	kill $M
	echo "== $variant: skew warnings $(grep -c 'clock skew' /tmp/gst-$variant.log), underflows $(grep -c underflow /tmp/gst-$variant.log), read errors $(grep -c 'error reading' /tmp/gst-$variant.log)"
	python3 - <<'PY'
import struct
d = open('/tmp/m.raw', 'rb').read()
s = struct.unpack('<%dh' % (len(d) // 2), d)
print('   earpiece monitor RMS per 0.5 s:', [int((sum(v*v for v in s[k:k+4000]) / max(1, len(s[k:k+4000]))) ** 0.5) for k in range(0, len(s), 4000)])
PY
done
kill $S
$CA 0 >/dev/null
