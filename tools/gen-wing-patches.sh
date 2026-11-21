#!/bin/bash
# Generate phoc 0005/0006 and phosh 0004/0005/0006 against upstream, check they apply on top of the aports' patches
set -e
S=$HOME/lg-wing-port/tools
WS=$HOME/lg-wing-port/pmaports/temp
UPHOC=~/phosh-src/phoc-0.58.0
UPHOSH=~/phosh-src/phosh-0.58.0
H=$(mktemp -d)

# gen <upstream> <script> <mode> <out> <header> files...
gen() {
	local U=$1 SCRIPT=$2 MODE=$3 OUT=$4 HDR=$5; shift 5
	local W; W=$(mktemp -d ~/phosh-src/wing.XXXX)
	for f in "$@"; do
		mkdir -p "$W/a/$(dirname $f)" "$W/b/$(dirname $f)"
		cp "$U/$f" "$W/a/$f"; cp "$U/$f" "$W/b/$f"
	done
	python3 -I "$SCRIPT" "$W/b" "$MODE"
	# phosh takes phoc's protocol file
	if [ "$MODE" = move ] && [ "$U" = "$UPHOSH" ]; then
		cp "$PHOC_XML" "$W/b/protocol/phosh-private.xml"
	fi
	( cd "$W"; { cat "$HDR"; for f in "$@"; do diff -u "a/$f" "b/$f" || true; done; } > "$OUT" )
	echo "$(basename $OUT): $(grep -c '^@@' $OUT) hunks"
	LAST=$W
}

cat > $H/phoc5 <<'EOF'
From: winglm port
Subject: [PATCH] input-method-relay: raise the OSK on every output

When a layer surface (e.g. the lock screen) wants text input the OSK is
moved to the overlay layer so it isn't hidden. That only happened on the
layer surface's own output, but the OSK may be on another one (LG Wing:
keyboard on the swivel screen below the main screen).
---
EOF
cat > $H/phoc6 <<'EOF'
From: winglm port
Subject: [PATCH] phosh-private: allow moving a toplevel to another output

New request move_toplevel_to_output (version 9): the shell asks to move a
toplevel to a given output or, with a null output, to the next enabled
one. The view keeps its maximized / fullscreen state.
---
EOF
cat > $H/phosh4 <<'EOF'
From: winglm port
Subject: [PATCH] rotation-manager: make forcing portrait on lock optional

New setting sm.puri.phosh.lockscreen force-portrait (default true, the old
behaviour). Devices that manage the orientation themselves (LG Wing: the
swivel screen) turn it off: the main screen is landscape in the T position
and the lock screen handles that by putting the keypad on the second
screen. Locking in portrait, opening the swivel and unlocking otherwise
"restored" portrait.

Also start without a saved transform: prelock_transform was 0 (normal),
so the first unlock of a session always turned the screen to portrait.
---
EOF
cat > $H/phosh5 <<'EOF'
From: winglm port
Subject: [PATCH] overview: move windows to the other screen

With more than one screen the running activities get a button that moves
their window to the next screen (phosh-private v9 move_toplevel_to_output,
bound only when the compositor offers it) and shows it there.

The protocol file is phoc's (version 8 plus the new request) so request
numbers match the compositor's.
---
EOF
cat > $H/phosh6 <<'EOF'
From: winglm port
Subject: [PATCH] home: app grid on the second screen in landscape

When the main screen is landscape and there's a second built-in screen
(LG Wing T position: the swivel screen below the main one) the app grid
moves to a layer surface on that screen, shown while the home is
unfolded. The main screen keeps the running apps. The grid moves back
before that surface goes away and when the main screen turns portrait.
---
EOF

gen $UPHOC $S/patch-phoc-move.py osk $WS/phoc/0005-input-method-relay-raise-osk-on-every-output.patch $H/phoc5 \
	src/input-method-relay.c
gen $UPHOC $S/patch-phoc-move.py move $WS/phoc/0006-phosh-private-move-toplevel-to-output.patch $H/phoc6 \
	protocols/phosh-private.xml src/view.h src/view.c src/phosh-private.c
PHOC_XML=$LAST/b/protocols/phosh-private.xml

gen $UPHOSH $S/patch-phosh-wing.py rotation $WS/phosh/0004-rotation-manager-force-portrait-setting.patch $H/phosh4 \
	data/mobi.phosh.shell.gschema.xml src/rotation-manager.c
gen $UPHOSH $S/patch-phosh-wing.py move $WS/phosh/0005-overview-move-windows-to-the-other-screen.patch $H/phosh5 \
	protocol/phosh-private.xml src/phosh-wayland.c src/toplevel.h src/toplevel.c src/activity.h src/activity.c src/ui/activity.ui src/overview.c
gen $UPHOSH $S/patch-phosh-wing.py grid $WS/phosh/0006-home-app-grid-on-second-screen.patch $H/phosh6 \
	src/home.c

# apply checks on top of the existing aport patches
for pkg in phoc phosh; do
	U=$UPHOC; [ $pkg = phosh ] && U=$UPHOSH
	T=$(mktemp -d ~/phosh-src/apply.XXXX)
	cp -r $U/. $T/
	cd $T
	for p in $WS/$pkg/0*.patch; do
		patch -p1 -s --dry-run < "$p" >/dev/null 2>&1 && patch -p1 -s < "$p" || echo "FAILED: $(basename $p)"
	done
	echo "$pkg: applied $(ls $WS/$pkg/0*.patch | wc -l) patches"
done
