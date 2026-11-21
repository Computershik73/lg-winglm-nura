#!/bin/sh
sudo mkdir -p /run/udev/rules.d
echo 'SUBSYSTEM=="net", KERNEL=="qmapmux*", ENV{ID_MM_QCOM_SOC}="1", ENV{ID_MM_PHYSDEV_UID}="qcom-soc"' | sudo tee /run/udev/rules.d/91-winglm-qmapmux.rules >/dev/null
sudo udevadm control --reload
