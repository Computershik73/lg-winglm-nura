#!/bin/sh
# build the ModemManager aport on the phone (source already in ~/distfiles)
cd ~/aports/modemmanager
export SRCDEST=$HOME/distfiles
abuild verify > /tmp/mm-verify.log 2>&1 || { echo "checksum differs from Alpine's (GitLab archive regenerated?)"; tail -3 /tmp/mm-verify.log; }
start=$(date +%s)
nice -n 5 abuild -d > /tmp/mm-abuild.log 2>&1 || { echo "abuild failed"; grep -E "error|ERROR|FAILED" /tmp/mm-abuild.log | head -30; tail -20 /tmp/mm-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
ls ~/.local/share/abuild/aports/aarch64/ | grep -E "^modemmanager-1|^libmm-glib"
