#!/bin/sh
# usage: sh -s <aport-name>   (APKBUILD in ~/aports/<name>, sources in ~/distfiles)
set -e
N=$1
P=http://127.0.0.1:8888
cd ~/aports/$N
deps=$(sh -c '. ./APKBUILD; echo $makedepends')
for try in 1 2 3; do
	if sudo env http_proxy=$P https_proxy=$P apk add $deps > /tmp/$N-deps.log 2>&1; then
		echo "deps ok (try $try)"; break
	fi
	tail -3 /tmp/$N-deps.log; sleep 3
done
grep -E 'Upgrading' /tmp/$N-deps.log | head -5 || true
export SRCDEST=$HOME/distfiles JOBS=$(nproc) MAKEFLAGS=-j$(nproc)
abuild checksum > /tmp/$N-checksum.log 2>&1 || { echo "checksum failed"; cat /tmp/$N-checksum.log; exit 1; }
start=$(date +%s)
abuild -d > /tmp/$N-abuild.log 2>&1 || { echo "abuild failed"; tail -40 /tmp/$N-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
grep -E '^>>> .*patching|patching file' /tmp/$N-abuild.log | head -3
ls ~/.local/share/abuild/aports/aarch64/ | grep -E "^$N-[0-9]"
