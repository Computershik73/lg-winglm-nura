#!/bin/bash
set -e
S=/mnt/c/Users/User/AppData/Local/Temp/claude/09dffbddec4c1633/dd1f1da9-6870-4ea2-9c9e-29465f940410/scratchpad
T=/mnt/c/MICD/profiles/d19bc6bc-1286-4caf-9fe1-c0fc5c4175a3/scratch-workspaces/7f4c33e3-713d-4694-9eaa-57d6e1528aa0/4559bdd3-f3f8-4a6b-afb9-1e62cbd0b548/scratch-2026-11-13-581527/pmaports/temp/callaudiod
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
