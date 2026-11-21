#!/bin/sh
try() { if amixer -c 0 -q cset "name=$1" "$2" 2>/dev/null; then echo "ok   $1 = $2"; else echo "FAIL $1 = $2"; amixer -c 0 cget "name=$1" 2>&1 | grep -E "type=|Items|Item #" | head -12; fi; }
try "TX DEC0 MUX" SWR_MIC
try "TX SMIC MUX0" ADC0
try "TX_CDC_DMA_TX_3 Channels" One
try "TX_AIF1_CAP Mixer DEC0" 1
try "ADC1_MIXER Switch" 1
try "ADC1 Volume" 6
try "TX_DEC0 Volume" 84
try "MultiMedia2 Mixer TX_CDC_DMA_TX_3" 1
try "MultiMedia1 Mixer TX_CDC_DMA_TX_3" 1
echo "== jacks / volumes"
amixer -c 0 controls | grep -iE "jack|MultiMedia1 Playback Volume|RX_RX0 Digital Volume|HPH. Volume|EAR.*Volume|PRI_MI2S.*Volume|TFA|Speaker" | head -20
