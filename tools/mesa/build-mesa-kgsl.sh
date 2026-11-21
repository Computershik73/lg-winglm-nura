#!/bin/sh
# Build Mesa with the Qualcomm KGSL kernel-mode backend on the phone itself.
# Installs into a separate prefix so the system Mesa stays untouched:
#   Vulkan : turnip (freedreno) on /dev/kgsl-3d0
#   GL/GLES: freedreno gallium on kgsl, plus zink on top of turnip
#
# Same version as Alpine's Mesa, so libgallium-$VER.so has the same name.
# With /opt/mesa-kgsl/lib first in the musl library path (see
# mesa-kgsl-system.sh) every client library Alpine links against
# libgallium (libEGL, libGL, libGLESv1_CM, libGLESv2) must come from this
# build too, hence GLX and GLES1 are enabled: Alpine's libGL against this
# libgallium fails with "loader_dri3_*: symbol not found".
#
# Build deps (Alpine): meson glslang python3 py3-mako py3-yaml bison flex
#   libdrm-dev wayland-dev wayland-protocols expat-dev zstd-dev
#   libx11-dev libxext-dev libxfixes-dev libxxf86vm-dev libxrandr-dev
#   libxshmfence-dev libxcb-dev
set -eu
VER=26.3.0
SRC="$HOME/mesa-$VER"
PREFIX=/opt/mesa-kgsl
stage="${1:-all}"

if [ ! -d "$SRC" ]; then
	tar -xf "$HOME/mesa-$VER.tar.xz" -C "$HOME"
fi
cd "$SRC"

if [ "$stage" = setup ] || [ "$stage" = all ]; then
	wipe=
	[ -d build ] && wipe=--wipe
	meson setup $wipe build \
		--prefix="$PREFIX" --libdir=lib --buildtype=release \
		-Db_ndebug=true \
		-Dplatforms=x11,wayland \
		-Dgallium-drivers=freedreno,zink \
		-Dvulkan-drivers=freedreno \
		-Dfreedreno-kmds=kgsl,msm \
		-Dllvm=disabled \
		-Dglx=dri \
		-Dgbm=enabled \
		-Degl=enabled \
		-Dgles1=enabled \
		-Dgles2=enabled \
		-Dopengl=true \
		-Dvideo-codecs= \
		-Dgallium-va=disabled \
		-Dgallium-rusticl=false \
		-Dvulkan-layers= \
		-Dtools= \
		-Dbuild-tests=false \
		-Dvalgrind=disabled \
		-Dlibunwind=disabled \
		-Dlmsensors=disabled \
		-Dzstd=enabled \
		-Dexpat=enabled
fi

if [ "$stage" = build ] || [ "$stage" = all ]; then
	ninja -C build -j"$(nproc)"
	sudo ninja -C build install
	echo "MESA-KGSL-DONE"
fi
