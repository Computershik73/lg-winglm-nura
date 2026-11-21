#!/bin/bash
# regenerate the calls aport (Alpine's recipe + our patches) and put it into
# the phone's ~/aports/calls.  usage: mkaport.sh PKGREL
set -e
REL=${1:?pkgrel}
PD=$(cd "$(dirname "$0")" && pwd)
P1=0001-dial-pad-window-on-a-second-screen.patch
P2=0002-sip-retry-registration-after-temporary-failures.patch
cd ~/calls-dl
rm -rf p && mkdir -p p/x
for d in a b c; do
	tar xJf calls-51.1.tar.xz -C p/x && mv p/x/calls-51.1 p/$d
done
rmdir p/x
python3 $PD/apply.py p/b $PD
python3 $PD/apply.py p/c $PD
python3 $PD/apply_sip_retry.py p/c
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
} > aport/$P1
{
cat <<'EOF'
From: winglm port
Subject: [PATCH] sip: retry the registration after temporary failures

An auto-connect account that gets 503 (or a timeout / 5xx) from its
registrar stayed offline until Calls was restarted. With a local gateway
that refuses registrations while its upstream (e.g. IMS) is not ready, the
account has to come back by itself: register again every 30 s.
---
EOF
(cd p && diff -ruN b c || true)
} > aport/$P2
sed -e "s/^pkgrel=0\$/pkgrel=$REL/" \
    -e 's|^source="https://download.gnome.org/sources/calls/${pkgver%%.\*}/calls-$pkgver.tar.xz"$|source="https://download.gnome.org/sources/calls/${pkgver%%.*}/calls-$pkgver.tar.xz\n\t'$P1'\n\t'$P2'\n\t"|' \
    APKBUILD > aport/APKBUILD
cd aport
python3 - "$P1" "$P2" <<'PY'
import hashlib, sys
p = 'APKBUILD'
s = open(p).read()
i = s.rindex('"')
add = ''.join('%s  %s\n' % (hashlib.sha512(open(f, 'rb').read()).hexdigest(), f) for f in sys.argv[1:])
open(p, 'w').write(s[:i] + add + '"\n')
PY
grep -n '^pkgrel' APKBUILD
ssh -o BatchMode=yes user@172.16.42.1 'rm -f ~/aports/calls/*.patch; mkdir -p ~/aports/calls'
scp -q -o BatchMode=yes APKBUILD $P1 $P2 user@172.16.42.1:aports/calls/
echo "aport r$REL on the phone ($(wc -l < $P1) + $(wc -l < $P2) patch lines)"
