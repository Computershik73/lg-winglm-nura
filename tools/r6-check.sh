#!/bin/sh
cat /proc/version | grep -o "#[0-9]*[^ ]* SMP[^)]*" | head -1; uname -v
cat /proc/uptime
# sx control: full range accepted now? read current, try 0 dB (84) only if current is 84 already (no change), then read info
amixer -c0 cget name='RX_RX0 Digital Volume' | tail -2
amixer -c0 cget name='RX_RX1 Digital Volume' | tail -1
rc-status default 2>/dev/null | grep -vE "started" | head
dmesg | grep -iE "panic|oops|BUG:|Unable to handle" | head -5
lsmod | grep -E "hci_uart|^bluetooth" | head
