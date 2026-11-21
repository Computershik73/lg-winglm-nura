#!/bin/sh
set -e
cd ~/aports/phosh
if [ ! -f ~/.abuild/abuild.conf ] || ! grep -q PACKAGER_PRIVKEY ~/.abuild/abuild.conf; then
	SUDO=sudo abuild-keygen -a -n -i 2>&1 | tail -2
fi
export SRCDEST=$HOME/distfiles
export JOBS=$(nproc)
export MAKEFLAGS=-j$JOBS
start=$(date +%s)
abuild -d > /tmp/phosh-abuild.log 2>&1 || { echo "abuild failed"; tail -30 /tmp/phosh-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
ls -la ~/packages/aports/aarch64/ | grep -E 'phosh'
