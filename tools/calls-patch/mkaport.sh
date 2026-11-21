#!/bin/bash
# regenerate the calls aport (Alpine's recipe + our patch) and put it into
# the phone's ~/aports/calls.  usage: mkaport.sh PKGREL
set -e
REL=${1:?pkgrel}
PD=$HOME/lg-wing-port/tools/calls-patch
P=0001-dial-pad-window-on-a-second-screen.patch
cd ~/calls-dl
rm -rf p && mkdir -p p/x p/y
tar xJf calls-51.1.tar.xz -C p/x && mv p/x/calls-51.1 p/a
tar xJf calls-51.1.tar.xz -C p/y && mv p/y/calls-51.1 p/b
rmdir p/x p/y
python3 $PD/apply.py p/b $PD
rm -rf aport && mkdir aport
{
cat <<'EOF'
From: winglm port
Subject: [PATCH] dial pad window on a second screen

On devices with a second screen (LG Wing: the swivel screen below the
main one when the swivel is open), show the dial pad there: while Calls
is in front and the monitor named in the new "dialpad-monitor" setting
is connected, a fullscreen window on it holds a compact dial pad and the
main window drops its Dial Pad page. During a call the window turns into
a DTMF keypad for the active call. Empty setting (default): unchanged.
---
EOF
(cd p && diff -ruN a b || true)
} > aport/$P
sed -e "s/^pkgrel=0\$/pkgrel=$REL/" \
    -e 's|^source="https://download.gnome.org/sources/calls/${pkgver%%.\*}/calls-$pkgver.tar.xz"$|source="https://download.gnome.org/sources/calls/${pkgver%%.*}/calls-$pkgver.tar.xz\n\t'$P'\n\t"|' \
    APKBUILD > aport/APKBUILD
cd aport
sum=$(sha512sum $P | cut -d' ' -f1)
python3 - "$sum" "$P" <<'PY'
import sys
p = 'APKBUILD'
s = open(p).read()
i = s.rindex('"')
s = s[:i] + '%s  %s\n"\n' % (sys.argv[1], sys.argv[2])
open(p, 'w').write(s)
PY
grep -n '^pkgrel' APKBUILD
ssh -o BatchMode=yes user@172.16.42.1 'mkdir -p ~/aports/calls'
scp -q -o BatchMode=yes APKBUILD $P user@172.16.42.1:aports/calls/
echo "aport r$REL on the phone ($(wc -l < $P) patch lines)"
