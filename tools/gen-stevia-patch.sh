#!/bin/bash
# Generate pmaports/temp/stevia/0001-osk-output-setting.patch from the upstream stevia source
set -e
S=$HOME/lg-wing-port/tools
P=$HOME/lg-wing-port/pmaports/temp/stevia
U=~/stevia-src/phosh-osk-stevia-0.58.0
FILES="data/mobi.phosh.osk.gschema.xml src/pos-output.h src/pos-output.c src/pos-size-manager.h src/pos-size-manager.c src/phosh-osk-stevia.c src/pos-input-surface.c"
W=$(mktemp -d ~/stevia-src/pw.XXXX)
for f in $FILES; do
	mkdir -p $W/a/$(dirname $f) $W/b/$(dirname $f)
	cp $U/$f $W/a/$f; cp $U/$f $W/b/$f
done
python3 -I $S/patch-stevia.py $W/b
cd $W
F=$P/0001-osk-output-setting.patch
{
cat <<'EOF'
From: winglm port
Subject: [PATCH] Allow putting the keyboard on a given output

New setting mobi.phosh.osk output: the connector name of the output the
keyboard should be shown on (LG Wing: the swivel screen below the main
one in its T position). The input surface is recreated when the setting
changes or that output comes or goes, and the keyboard gets sized for it.

Also recreate the input surface when the compositor closes it (its output
went away): the dangling pointer kept maybe_create_input_surface() from
doing anything, leaving the session without a keyboard. A new input surface
waits for the old one's input method to go (the compositor hands out one
per seat) and the first surface's one-shot key press timer is removed when
that surface goes away before it fires (it used a freed driver).
---
EOF
for f in $FILES; do diff -u a/$f b/$f || true; done
} > "$F"
echo "hunks: $(grep -c '^@@' "$F")"
# compile check of the touched C files against the upstream tree
B=$(mktemp -d ~/stevia-src/build.XXXX)
cp -r $U/. $B/
cd $B && patch -p1 -s < "$F" && echo "applies cleanly"
