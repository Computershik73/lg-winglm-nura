#!/bin/bash
# commit the Calls dial pad work to ~/lg-wing-port (only our own changes)
set -e
SP=/mnt/c/Users/User/AppData/Local/Temp/claude/09dffbddec4c1633/dd1f1da9-6870-4ea2-9c9e-29465f940410/scratchpad
W=/mnt/c/MICD/profiles/d19bc6bc-1286-4caf-9fe1-c0fc5c4175a3/scratch-workspaces/7f4c33e3-713d-4694-9eaa-57d6e1528aa0/4559bdd3-f3f8-4a6b-afb9-1e62cbd0b548/scratch-2026-11-13-581527/pmaports/device/testing/device-lg-winglm
cd ~/lg-wing-port
D=pmaports/device/testing/device-lg-winglm

# 1. Alpine fork: the aport as built on the phone
mkdir -p aports/calls
cp ~/calls-dl/aport/APKBUILD ~/calls-dl/aport/0001-dial-pad-window-on-a-second-screen.patch aports/calls/
ssh -o BatchMode=yes user@172.16.42.1 'sha512sum ~/aports/calls/*' | awk '{print $1}' > /tmp/phone.sums
sha512sum aports/calls/* | awk '{print $1}' | diff -q - /tmp/phone.sums >/dev/null && echo "aport matches the phone"

# 2. device package: the override + only our APKBUILD lines (pkgrel 32 is
#    the VoLTE session's)
cp $W/90_winglm-calls.gschema.override $D/
python3 - $D/APKBUILD <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = '\t90_winglm-phosh.gschema.override\n'
assert s.count(a) == 1
s = s.replace(a, a + '\t90_winglm-calls.gschema.override\n')
b = ('\tinstall -Dm644 "$srcdir"/90_winglm-phosh.gschema.override \\\n'
     '\t\t"$subpkgdir"/usr/share/glib-2.0/schemas/90_winglm-phosh.gschema.override\n')
assert s.count(b) == 1
s = s.replace(b, b + '\t# Calls (patched): dial pad on the swivel screen while it is on\n'
              '\tinstall -Dm644 "$srcdir"/90_winglm-calls.gschema.override \\\n'
              '\t\t"$subpkgdir"/usr/share/glib-2.0/schemas/90_winglm-calls.gschema.override\n')
open(p, 'w').write(s)
PY

# 3. tools: the patch sources and build helpers
mkdir -p tools/calls-patch
cp $SP/calls-patch/{calls-dialpad-window.c,calls-dialpad-window.h,apply.py,mkaport.sh,commit.sh} tools/calls-patch/
cp $SP/{calls-prep.sh,calls-abuild.sh,calls-install.sh} tools/

git add aports/calls $D/90_winglm-calls.gschema.override $D/APKBUILD tools/calls-patch tools/calls-prep.sh tools/calls-abuild.sh tools/calls-install.sh
git diff --cached --stat
git commit -q -F - <<'EOF'
calls: dial pad window on the swivel screen

GNOME Calls 51.1 fork (aports/calls, r2, built natively on the phone):
while Calls is in front and the monitor named in the new
org.gnome.Calls "dialpad-monitor" setting is connected, a fullscreen
window on it holds a compact dial pad (the swivel screen is only
360x413 logical pixels at scale 3) and the main window drops its Dial
Pad page; during a call it is a DTMF keypad for the active call.
Empty setting: Calls behaves as before.

device-lg-winglm-phosh: 90_winglm-calls.gschema.override sets
dialpad-monitor='DSI-2'.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline | head -3
git status --short | head
