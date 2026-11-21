#!/bin/sh
# Re-register the sound card so the TFA98xx component probe loads its container again
D=/sys/bus/platform/drivers/kona-asoc-snd
DEV=$(ls $D | grep -vE 'bind|uevent|module' | head -1)
echo "machine device: $DEV"
M=$(dmesg | wc -l)
echo "$DEV" > $D/unbind
sleep 2
cat /proc/asound/cards
echo "$DEV" > $D/bind
sleep 6
cat /proc/asound/cards
dmesg | tail -n +$M | grep -iE 'tfa|container|cnt|snd-card|asoc.*err|failed' | grep -v 'no backend DAIs' | head -20 | cut -c1-170
cat /sys/kernel/debug/*/fw-state 2>/dev/null; ls /sys/kernel/debug 2>/dev/null | grep -i tfa
