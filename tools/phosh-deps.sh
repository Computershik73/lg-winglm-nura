#!/bin/sh
set -e
P=http://127.0.0.1:8888
cd ~/aports/phosh
ls
# makedepends straight from the APKBUILD
deps=$(sh -c '. ./APKBUILD; echo $makedepends')
echo "deps: $deps"
sudo env http_proxy=$P https_proxy=$P apk update 2>&1 | tail -2
for try in 1 2 3; do
	if sudo env http_proxy=$P https_proxy=$P apk add abuild build-base $deps > /tmp/phosh-deps.log 2>&1; then
		echo "deps installed (try $try)"; break
	fi
	echo "apk add failed (try $try):"; tail -3 /tmp/phosh-deps.log
	sleep 3
done
tail -2 /tmp/phosh-deps.log
id -nG user | grep -qw abuild || sudo addgroup user abuild
df -h / | tail -1
