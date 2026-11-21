#!/bin/bash
set -e
S=$HOME/lg-winglm-nura/tools
WS=$HOME/lg-winglm-nura/pmaports/temp
UPHOSH=~/phosh-src/phosh-0.58.0
OUT=$WS/phosh/0008-lockscreen-manager-forget-a-closed-lockscreen.patch
W=$(mktemp -d ~/phosh-src/lockd.XXXX)
mkdir -p $W/base; cp -r $UPHOSH/. $W/base/
cd $W/base; for p in $WS/phosh/000[1-7]*.patch; do patch -p1 -s < "$p"; done
mkdir -p $W/a/src $W/b/src
cp $W/base/src/lockscreen-manager.c $W/a/src/; cp $W/base/src/lockscreen-manager.c $W/b/src/
python3 -I $S/patch-phosh-lockdestroy.py $W/b
cd $W
{
cat <<'H'
From: winglm port
Subject: [PATCH] lockscreen-manager: forget a lockscreen the compositor closed

The compositor closes a lockscreen whose output is gone, and that can
happen right after it was created: locked at session start, the screens
get blanked one after the other (blanking disables the outputs) and the
lockscreen moves to a primary monitor that is going away too. The
manager kept the pointer to the destroyed widget and the keypad
placement (0002) used it right away: the shell crashed during startup.
Clear the pointer on destroy and let unlocking work without a
lockscreen; a new one comes with the next primary monitor.
---
H
diff -u a/src/lockscreen-manager.c b/src/lockscreen-manager.c || true
} > $OUT
echo "$(basename $OUT): $(grep -c '^@@' $OUT) hunks"
T=$(mktemp -d ~/phosh-src/apply.XXXX); cp -r $UPHOSH/. $T/; cd $T
for p in $WS/phosh/0*.patch; do patch -p1 -s < "$p" || echo "FAILED: $(basename $p)"; done
echo "applied $(ls $WS/phosh/0*.patch | wc -l) patches"
