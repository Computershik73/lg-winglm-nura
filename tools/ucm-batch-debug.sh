#!/bin/sh
v() { amixer -c 0 cget "name=$1" | sed -n "s/.*: values=//p"; }
(
	echo 'set _verb "Voice Call"'; echo "set _enadev Earpiece"; echo "set _enadev Mic"; echo "list _enadevs"; sleep 1
	echo "  before: PRI-MM1=$(v 'PRI_MI2S_RX Audio Mixer MultiMedia1')" >&2
	echo "set _disdev Earpiece"; echo "set _enadev Speaker"; echo "list _enadevs"; sleep 1.5
	echo "  after: PRI-MM1=$(v 'PRI_MI2S_RX Audio Mixer MultiMedia1') RX0-MM1=$(v 'RX_CDC_DMA_RX_0 Audio Mixer MultiMedia1')" >&2
	echo 'set _verb HiFi'; sleep 0.5; echo reset
) | alsaucm -c hw:0 -b - 2>&1 | grep -v "^$"
