#!/bin/sh
date +%T
echo "=== spk-gain service"
sudo tail -n 30 /var/log/winglm-spk-gain.log
echo "=== call volume helper"
tail -n 30 /tmp/call-volume.log
echo "=== calls (trace)"
sudo grep -aE "MO call|MT call|connected|hangup|answered|early media|callaudiod mode" /var/log/winglm-volte.trace | awk '$1 >= "14:2"' | tail -15 | cut -c1-110
echo "=== amp now"
sudo python3 /tmp/tfa-read.py | tail -1
