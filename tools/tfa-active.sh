#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
python3 /tmp/tone.py /tmp/tone4.wav 4 -30
$E pactl get-default-sink
$E paplay /tmp/tone4.wav &
sleep 2
sudo python3 /tmp/tfa-read.py 0x02 0x52 0x5f
amixer -c0 cget name='SPK Profile' | tail -1
wait
sleep 2
sudo python3 /tmp/tfa-read.py 0x52 0x5f | tail -1
