#!/bin/sh
set -e
cd ~/aports/calls
export SRCDEST=$HOME/distfiles
export JOBS=$(nproc)
export MAKEFLAGS=-j$JOBS
start=$(date +%s)
abuild -d > /tmp/calls-abuild.log 2>&1 || { echo "abuild failed"; grep -E 'error|Error|FAILED' /tmp/calls-abuild.log | head -30; tail -20 /tmp/calls-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
ls -la ~/packages/aports/aarch64/ | grep -E 'calls'
