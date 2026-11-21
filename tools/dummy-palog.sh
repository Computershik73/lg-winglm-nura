#!/bin/sh
CPID=$(pgrep -u $(id -u) -x callaudiod | head -1)
export $(tr '\0' '\n' < /proc/$CPID/environ | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=')
C=alsa_card.platform-soc_qcom_msm-audio-apr_qcom_q6core-audio_sound
pacmd set-log-level 4
pactl set-card-profile $C "HiFi (Earpiece, Mic)"; sleep 1
pactl set-card-profile $C "HiFi (Mic, Speaker)"; sleep 2
pacmd set-log-level 1
sudo logread 2>/dev/null | grep -a pulseaudio | grep -aiE 'alsa|ucm|sink|fail|error|cannot|unable|mapping|device' | tail -40 | cut -c1-230
