#!/bin/sh
# GPU-accelerated sway on both LG Wing panels using the KGSL Mesa build:
# wlroots gles2 -> zink -> turnip -> /dev/kgsl-3d0, scanout via msm SDE.
set -eu
M=/opt/mesa-kgsl
export XDG_RUNTIME_DIR=/tmp/xdg-user
mkdir -p -m 700 "$XDG_RUNTIME_DIR"
export LIBSEAT_BACKEND=seatd
export WLR_RENDERER=gles2
export LD_LIBRARY_PATH=$M/lib
export LIBGL_DRIVERS_PATH=$M/lib/dri
export GBM_BACKENDS_PATH=$M/lib/gbm
export MESA_LOADER_DRIVER_OVERRIDE=zink
export VK_ICD_FILENAMES=$M/share/vulkan/icd.d/freedreno_icd.aarch64.json
export TU_DEBUG=startup

cfg=/tmp/sway-gpu.conf
cat > "$cfg" <<'EOF'
output Virtual-1 disable
output DSI-1 pos 0 0 scale 3
output DSI-2 pos 360 0 scale 3
default_border none
workspace 1 output DSI-1
workspace 2 output DSI-2
exec /bin/sh -c 'sleep 2; /usr/bin/swaymsg workspace 2; /usr/bin/vkcube --wsi wayland & sleep 3; /usr/bin/swaymsg workspace 1; /usr/bin/es2gears_wayland -fullscreen'
EOF

pkill -x sway 2>/dev/null || true
cp -f /usr/bin/sway /tmp/sway-nocap  # copy drops cap_sys_nice, else LD_LIBRARY_PATH/VK_ICD_FILENAMES are ignored
exec /tmp/sway-nocap -c "$cfg" -d > /tmp/sway-gpu.log 2>&1
