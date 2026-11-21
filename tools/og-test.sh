#!/bin/sh
sed -n '/^output_geometry/,/^}/p' /tmp/wpr.sh > /tmp/og.sh
cat >> /tmp/og.sh <<'EOF'
randr() { _d=$1 _s=$2; shift 2; XDG_RUNTIME_DIR=$_d WAYLAND_DISPLAY=$_s wlr-randr "$@"; }
for o in DSI-1 DSI-2; do echo "$o: $(output_geometry /run/user/108 wayland-0 $o)"; done
EOF
sudo sh /tmp/og.sh
