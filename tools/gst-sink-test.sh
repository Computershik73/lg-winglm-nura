#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
RX='udpsrc port=5004 caps="application/x-rtp,media=audio,clock-rate=8000,encoding-name=PCMA,payload=8"'
$E gst-launch-1.0 -q audiotestsrc is-live=true freq=700 volume=0.2 ! audio/x-raw,rate=8000,channels=1 ! alawenc ! rtppcmapay ! udpsink host=127.0.0.1 port=5004 > /dev/null 2>&1 &
S=$!
sleep 0.5
echo "== plain: udpsrc ! rtpjitterbuffer ! depay ! alawdec ! pulsesink"
$E timeout 4 gst-launch-1.0 -m $RX ! rtpjitterbuffer ! rtppcmadepay ! alawdec ! audioconvert ! audioresample ! pulsesink name=snk 2>&1 | grep -E "Setting pipeline|state-changed.*snk|New clock|ERROR|WARN" | head -8
echo "== with rtpbin (like Calls)"
$E timeout 4 gst-launch-1.0 -m rtpbin name=rb $RX ! rb.recv_rtp_sink_0 rb. ! rtppcmadepay ! alawdec ! audioconvert ! audioresample ! pulsesink name=snk 2>&1 | grep -E "Setting pipeline|state-changed.*snk|New clock|ERROR|WARN" | head -8
echo "== with rtpbin + pulsesrc in the same pipeline"
$E timeout 4 gst-launch-1.0 -m rtpbin name=rb $RX ! rb.recv_rtp_sink_0 rb. ! rtppcmadepay ! alawdec ! audioconvert ! audioresample ! pulsesink name=snk \
	pulsesrc name=src ! audioconvert ! audioresample ! audio/x-raw,rate=8000,channels=1 ! alawenc ! rtppcmapay ! rb.send_rtp_sink_0 rb.send_rtp_src_0 ! udpsink host=127.0.0.1 port=5010 2>&1 | grep -E "Setting pipeline|state-changed.*(snk|src)|New clock|ERROR|WARN" | head -10
kill $S
