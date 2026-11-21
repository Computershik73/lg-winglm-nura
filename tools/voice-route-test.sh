#!/bin/sh
# can the VoiceMMode1 PCM open in the HiFi (non-call) verb once only the
# voice mixer routes are set?
c() { amixer -c 0 cset name="$1" "$2" >/dev/null 2>&1 && echo "set $1=$2" || echo "FAILED $1"; }
g() { amixer -c 0 cget name="$1" | sed -n 's/.*: values=//p'; }
echo "before: rx=$(g 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1') tx=$(g 'VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1')"
echo "== without voice routes:"
python3 /tmp/volte/voice-open.py hw:0,2 1 2>&1 | grep -E 'set_params|prepare'
c 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1' 1
c 'VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1' 1
echo "== with voice routes:"
python3 /tmp/volte/voice-open.py hw:0,2 1 2>&1 | grep -E 'set_params|prepare'
c 'RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1' 0
c 'VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1' 0
