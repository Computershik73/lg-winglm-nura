#!/bin/sh
# Read-only hardware survey (no writes, no module loading)
echo "== kernel"; uname -r
echo "== modules dir"; ls /lib/modules/$(uname -r) 2>/dev/null | head; find /lib/modules/$(uname -r) -name '*.ko*' 2>/dev/null | wc -l
echo "== lsmod"; lsmod 2>/dev/null | head -20
C=/proc/config.gz
if [ -r $C ]; then
	echo "== config (selected)"
	zcat $C | grep -E '^CONFIG_(MODULES|CNSS2?|CNSS_GENL|QCA_CLD_WLAN|WLAN|CFG80211|MAC80211|BT|BT_QCA|BT_HCIUART|BT_HCIUART_QCA|MSM_BT_POWER|BTFM_SLIM|SND|SND_SOC|SND_SOC_QDSP6V2|MSM_QDSP6.*|QCOM_Q6V5.*|MSM_ADSP_LOADER|QRTR.*|IPC_ROUTER.*|MSM_IPC_ROUTER.*|IPA3?|RMNET.*|MSM_RMNET.*|QCOM_SMEM|MSM_SUBSYSTEM_RESTART|MSM_PIL.*|QCOM_SYSMON|RPMSG.*|MSM_QMI_INTERFACE|QCOM_QMI_HELPERS|SPECTRA_CAMERA|MSM_CAMERA.*|INPUT_FINGERPRINT|FINGERPRINT.*|QSEECOM|UIO.*|LGE_.*FP.*|SDX.*|MHI.*|ESOC.*)=' | sort | head -80
else
	echo "no /proc/config.gz"
fi
echo "== asound"; cat /proc/asound/cards 2>/dev/null; ls /dev/snd 2>/dev/null | head
echo "== net"; ls /sys/class/net
echo "== bluetooth"; ls /sys/class/bluetooth 2>/dev/null; ls /dev/ttyHS* /dev/ttyMSM* 2>/dev/null
echo "== remoteproc/subsys"; ls /sys/class/remoteproc 2>/dev/null; for s in /sys/bus/msm_subsys/devices/*; do [ -e "$s/name" ] && echo "$(cat $s/name 2>/dev/null): $(cat $s/state 2>/dev/null)"; done 2>/dev/null | head -20
echo "== video/camera nodes"; ls /dev/video* /dev/v4l-subdev* /dev/media* 2>/dev/null | head; ls /sys/class/video4linux 2>/dev/null | head
echo "== qseecom/fp"; ls -la /dev/qseecom /dev/*fp* /dev/goodix* /dev/qbt* 2>/dev/null; ls /sys/bus/platform/devices | grep -iE 'fp|fingerprint|goodix|qbt|egis|fpc' | head
echo "== firmware dir"; ls /lib/firmware | head -40; ls /lib/firmware/qcom 2>/dev/null | head
echo "== dmesg hits"
dmesg 2>/dev/null | grep -iE 'cnss|wlan|qca|bluetooth|hci|adsp|cdsp|modem|pil|subsys|q6|apr |snd|audio|asoc|ipa|rmnet|mhi|qrtr|ipc_router|fingerprint|fp_|qbt|goodix|cam_|camera' | grep -viE 'lg_..._audio_none' | tail -60
