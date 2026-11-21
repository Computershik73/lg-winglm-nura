#!/bin/sh
# Does a line written to /dev/kmsg reach "dmesg --follow-new | while read" promptly?
( timeout 4 dmesg --follow-new | while read -r l; do echo "GOT: $l"; done > /tmp/kt1.txt ) &
sleep 1; echo "<3>winglm-test-line-1" > /dev/kmsg; wait
echo "plain pipe: $(cat /tmp/kt1.txt)"
echo "stdbuf: $(command -v stdbuf)"
( timeout 4 stdbuf -oL dmesg --follow-new | while read -r l; do echo "GOT: $l"; done > /tmp/kt2.txt ) &
sleep 1; echo "<3>winglm-test-line-2" > /dev/kmsg; wait
echo "stdbuf pipe: $(cat /tmp/kt2.txt)"
