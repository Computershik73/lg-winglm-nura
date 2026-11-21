#!/bin/bash
set -e
S=$HOME/lg-wing-port/tools
T=$HOME/lg-wing-port/pmaports/temp/callaudiod
OUT=$T/0001-pulse-profile-per-device-and-dsp-voice-mute.patch
cd ~/winglm/cad
rm -rf a b; mkdir -p a/src b/src
cp callaudiod-0.1.99/src/cad-pulse.c a/src/; cp callaudiod-0.1.99/src/cad-pulse.c b/src/
python3 -I $S/patch-callaudiod.py b
{
cat <<'H'
From: winglm port
Subject: [PATCH] pulse: speaker with one profile per device, mute the DSP voice

PulseAudio 15 and later give every UCM device its own mapping. Devices on
the same PCM, like the earpiece and the speaker of most phones, are then
not ports of one sink but sit in different profiles of the same verb
("Voice Call (Earpiece, Mic)", "Voice Call (Mic, Speaker)"), and switching
the sink port fails ("No such entity"). When the sink doesn't have the
wanted port, switch to the best available profile of the active verb that
has it. When leaving a call, don't: the default profile follows anyway.

On Qualcomm downstream kernels (msm-pcm-voice) the call's microphone goes
to the modem through the DSP and never reaches PulseAudio; also set the
card's "Voice Tx Mute" control (all voice sessions) when muting.
---
H
diff -u a/src/cad-pulse.c b/src/cad-pulse.c || true
} > $OUT
echo "$(basename $OUT): $(grep -c '^@@' $OUT) hunks"
scp -q callaudiod-0.1.99.tar.gz user@172.16.42.1:distfiles/
