#!/bin/sh
UID_=$(id -u user)
t0=$(date +%s.%N)
sudo -u user env XDG_RUNTIME_DIR=/run/user/$UID_ HOME=/home/user parec --raw --rate=16000 --channels=1 --format=s16le \
	--latency-msec=20 --property=media.role=phone --property=filter.suppress=echo-cancel 2>/tmp/parec.err | \
	timeout 8 gst-launch-1.0 -q -e fdsrc fd=0 num-buffers=200 blocksize=640 do-timestamp=true ! \
	rawaudioparse use-sink-caps=false format=pcm pcm-format=s16le sample-rate=16000 num-channels=1 ! \
	audioconvert ! level interval=1000000000 post-messages=true ! voamrwbenc band-mode=2 ! fakesink > /dev/null 2>&1
t1=$(date +%s.%N)
echo "200 x 20 ms blocks through the AMR-WB encoder in $(echo "$t1 - $t0" | bc) s (4.0 s = real time)"
cat /tmp/parec.err | head -2
