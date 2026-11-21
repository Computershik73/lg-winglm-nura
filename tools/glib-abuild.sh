#!/bin/sh
set -e
P=http://127.0.0.1:8888
cd ~/aports/glib
deps=$(sh -c '. ./APKBUILD; echo $makedepends')
echo "deps: $deps"
for try in 1 2 3; do
	if sudo env http_proxy=$P https_proxy=$P apk add $deps > /tmp/glib-deps.log 2>&1; then
		echo "deps ok (try $try)"; break
	fi
	tail -3 /tmp/glib-deps.log; sleep 3
done
export SRCDEST=$HOME/distfiles http_proxy=$P https_proxy=$P
export JOBS=$(nproc) MAKEFLAGS=-j$(nproc)
start=$(date +%s)
abuild -d > /tmp/glib-abuild.log 2>&1 || { echo "abuild failed"; tail -40 /tmp/glib-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
ls ~/.local/share/abuild/aports/aarch64/ | grep -E '^glib'
