#!/bin/bash
# Generate phosh 0007 (home bar on the second screen) on top of 0006, check the whole series applies
set -e
S=$HOME/lg-wing-port/tools
WS=$HOME/lg-wing-port/pmaports/temp
UPHOSH=~/phosh-src/phosh-0.58.0
OUT=$WS/phosh/0007-home-bar-on-second-screen.patch
W=$(mktemp -d ~/phosh-src/swipe.XXXX)
cp -r $UPHOSH/. $W/a/ 2>/dev/null || { mkdir -p $W/a; cp -r $UPHOSH/. $W/a/; }
cd $W/a
for p in $WS/phosh/000[1-6]*.patch; do patch -p1 -s < "$p"; done
mkdir -p $W/b/src
cp $W/a/src/home.c $W/b/src/home.c
mkdir -p $W/aa/src; cp $W/a/src/home.c $W/aa/src/home.c
python3 -I $S/patch-phosh-swipe.py $W/b
cd $W
{
cat <<'EOF'
From: winglm port
Subject: [PATCH] home: home bar on the second screen

While the app grid lives on the second screen (patch 0006, LG Wing T
position) that screen also gets a home bar: swiping up on it opens the
overview, swiping down closes it and a tap toggles it, like the home bar
on the main screen. It reserves its height so windows don't cover it.

Also keep the focus off the app grid's search entry when that screen's
grid is shown: GTK focused the first focusable widget, the search entry,
and the on-screen keyboard came up over the grid on every unfold.

And don't pick a monitor that is being removed: the monitor manager
disposes it (wl_output gone) before emitting monitor-removed and only
drops it from its list afterwards, so the grid and bar surfaces got
created on a dead wl_output and the compositor dropped the shell
("unknown object ... get_layer_surface") when the swivel closed.

And stop placing the app grid once the home is disposed (the shell
replaces it when the primary monitor changes, e.g. both screens blanked
at startup): the monitor signals stay connected until finalize and the
overview was already gone. Placement updates requested while one runs
(mapping a surface does a roundtrip, monitors come and go meanwhile) are
run after it instead of inside it.
---
EOF
mv aa a.orig; mkdir -p a2/src; cp a.orig/src/home.c a2/src/home.c
diff -u --label a/src/home.c --label b/src/home.c a2/src/home.c b/src/home.c || true
} > $OUT
echo "$(basename $OUT): $(grep -c '^@@' $OUT) hunks"
# full series applies on upstream
T=$(mktemp -d ~/phosh-src/apply.XXXX)
cp -r $UPHOSH/. $T/
cd $T
for p in $WS/phosh/0*.patch; do
	patch -p1 -s < "$p" || echo "FAILED: $(basename $p)"
done
echo "applied $(ls $WS/phosh/0*.patch | wc -l) patches in $T"
gcc -fsyntax-only -x c /dev/null 2>/dev/null && echo "(no syntax check: needs phosh headers)"
