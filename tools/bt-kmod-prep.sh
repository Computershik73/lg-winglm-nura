#!/bin/bash
# WSL: unpack the r4 kernel source into the pmbootstrap native chroot with config + Module.symvers
set -e
W=$(pmbootstrap config work)
C=$W/chroot_native
A=/mnt/c/MICD/profiles/d19bc6bc-1286-4caf-9fe1-c0fc5c4175a3/scratch-workspaces/7f4c33e3-713d-4694-9eaa-57d6e1528aa0/4559bdd3-f3f8-4a6b-afb9-1e62cbd0b548/scratch-2026-11-13-581527/pmaports/device/testing/linux-lg-winglm
K=$C/home/pmos/kbt
sudo rm -rf $K; sudo mkdir -p $K
sudo tar xzf $W/cache_distfiles/linux-lg-winglm-f16d8d7345901bb1933f25acedeb60c07cf0d2bb.tar.gz -C $K
S=$(ls -d $K/android_kernel_lge_sm7250-*)
cd $S
for p in $A/0*.patch; do sudo patch -p1 -s < $p; done
sudo mkdir -p $S/out
sudo cp $A/config-lg-winglm.aarch64 $S/out/.config
sudo cp ~/winglm/bt/Module.symvers $K/Module.symvers.vmlinux
sudo cp /mnt/c/Users/User/AppData/Local/Temp/claude/09dffbddec4c1633/dd1f1da9-6870-4ea2-9c9e-29465f940410/scratchpad/bt-kmod-build.sh $K/build.sh
echo "source at ${S#$C}"
du -sh $K
