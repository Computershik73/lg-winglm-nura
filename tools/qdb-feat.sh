#!/bin/sh
grep -aiE "ModemFeature|vocoder_interface|VocoderIF|eVocoder|QCT_VS|MMPF_Voice_QCT_VS|MMPFAudioSystem|AudioSystem::|IMMPFAudio|vsid|asid" /tmp/qdb.txt | grep -aiE "mmpf|lgims|lrtp" | cut -d: -f5- | cut -c1-200 | sort -u | head -80
