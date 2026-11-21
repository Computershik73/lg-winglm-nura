#!/bin/bash
# WSL: unpack the r4 kernel source into the pmbootstrap native chroot with config + Module.symvers
set -e
W=$(pmbootstrap config work)
C=$W/chroot_native
A=$HOME/lg-winglm-nura/pmaports/device/testing/linux-lg-winglm
K=$C/home/pmos/kbt
sudo rm -rf $K; sudo mkdir -p $K
sudo tar xzf $W/cache_distfiles/linux-lg-winglm-f16d8d7345901bb1933f25acedeb60c07cf0d2bb.tar.gz -C $K
S=$(ls -d $K/android_kernel_lge_sm7250-*)
cd $S
for p in $A/0*.patch; do sudo patch -p1 -s < $p; done
sudo mkdir -p $S/out
sudo cp $A/config-lg-winglm.aarch64 $S/out/.config
sudo cp ~/winglm/bt/Module.symvers $K/Module.symvers.vmlinux
sudo cp $HOME/lg-winglm-nura/tools/bt-kmod-build.sh $K/build.sh
echo "source at ${S#$C}"
du -sh $K
