#!/bin/sh
# Earpiece voice route (LG voicemmode1-call handset + voice-handset), then hold VoiceMMode1 open
c() { amixer -c 0 -q cset "name=$1" "$2" || echo "  cset failed: $1"; }
c "RX_MACRO RX0 MUX" AIF1_PB
c "RX_CDC_DMA_RX_0 Channels" One
c "RX INT0_1 MIX1 INP0" RX0
c "RX INT0 DEM MUX" CLSH_DSM_OUT
c "EAR_RDAC Switch" 1
c "RDAC3_MUX" RX1
c "RX_EAR Mode" ON
c "TX DEC0 MUX" SWR_MIC
c "TX SMIC MUX0" ADC0
c "TX_CDC_DMA_TX_3 Channels" One
c "TX_AIF1_CAP Mixer DEC0" 1
c "ADC1_MIXER Switch" 1
c "RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 1
c "VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" 1
N0=$(dmesg | wc -l)
python3 /tmp/voice-open.py hw:0,2 6
sleep 1
dmesg | tail -n +$N0 | grep -iE "voice|voc_|mvm|cvs|cvp|afe|dpcm|asoc|q6|apr|error|fail" | head -25 | cut -c1-170
c "RX_CDC_DMA_RX_0_Voice Mixer VoiceMMode1" 0
c "VoiceMMode1_Tx Mixer TX_CDC_DMA_TX_3_MMode1" 0
c "EAR_RDAC Switch" 0
c "RX_EAR Mode" OFF
c "RX_MACRO RX0 MUX" ZERO
echo "subsystems: $(for s in /sys/bus/msm_subsys/devices/*; do printf '%s=%s ' $(cat $s/name) $(cat $s/state); done | grep -oE '(adsp|modem)=[A-Z]+' | tr '\n' ' ')"
