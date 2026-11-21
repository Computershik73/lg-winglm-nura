#!/bin/sh
# build the mesa-kgsl aport on the phone (sources already local)
set -e
cd ~/aports/mesa-kgsl
export SRCDEST=$HOME/distfiles
[ -f $SRCDEST/mesa-26.3.0.tar.xz ] || cp ~/mesa-26.3.0.tar.xz $SRCDEST/
abuild checksum >/dev/null
start=$(date +%s)
abuild -d > /tmp/mesa-abuild.log 2>&1 || { echo "abuild failed"; grep -E 'error|ERROR|FAILED' /tmp/mesa-abuild.log | head -30; tail -20 /tmp/mesa-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
ls -la ~/.local/share/abuild/aports/aarch64/ | grep mesa-kgsl
