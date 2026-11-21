#!/bin/bash
# Regenerate phosh patches 0002 and 0003 from the upstream source in ~/phosh-src
set -e
S=$HOME/lg-wing-port/tools
P=$HOME/lg-wing-port/pmaports/temp/phosh
U=~/phosh-src/phosh-0.58.0/src

# 0002: keypad (keep the existing header)
F2=$P/0002-lockscreen-keypad-on-second-screen-in-landscape.patch
HDR=$(mktemp)
sed '/^--- a\//,$d' "$F2" > "$HDR"
W=$(mktemp -d ~/phosh-src/kppw.XXXX)
mkdir -p $W/a/src $W/b/src
for f in lockscreen.c lockscreen.h lockshield.c lockshield.h lockscreen-manager.c; do
	cp $U/$f $W/a/src/; cp $U/$f $W/b/src/
done
python3 -I $S/patch-phosh-keypad.py $W/b/src
cd $W
{ cat "$HDR"; for f in lockscreen.h lockscreen.c lockshield.h lockshield.c lockscreen-manager.c; do diff -u a/src/$f b/src/$f || true; done; } > "$F2"
echo "0002 hunks: $(grep -c '^@@' "$F2")"

# 0003: monitor-added only once
F3=$P/0003-monitor-manager-announce-a-monitor-only-once.patch
W3=$(mktemp -d ~/phosh-src/mmpw.XXXX)
mkdir -p $W3/a/src $W3/b/src
cp $U/monitor-manager.c $W3/a/src/; cp $U/monitor-manager.c $W3/b/src/
python3 -I $S/patch-phosh-monitor.py $W3/b/src
cd $W3
{
cat <<'EOF'
From: winglm port
Subject: [PATCH] monitor-manager: announce a monitor only once

on_monitor_configured() emitted 'monitor-added' before disconnecting from
the monitor's 'configured' signal. The lockscreen manager reacts to
'monitor-added' by mapping a lock shield, and mapping a layer surface runs
a Wayland roundtrip. For a hotplugged output that roundtrip delivers the
xdg-output name and position plus the next wl_output.done, so the monitor
is 'configured' again and announced a second time from within the first
emission: the output ends up with two lock shields stacked on each other.

Disconnect before emitting.
---
EOF
diff -u a/src/monitor-manager.c b/src/monitor-manager.c || true
} > "$F3"
echo "0003 hunks: $(grep -c '^@@' "$F3")"
