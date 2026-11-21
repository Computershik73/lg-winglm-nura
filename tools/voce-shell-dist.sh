#!/bin/sh
# Voce shell: source tarball + aport to the phone, then build it there.
#
#   tools/voce-shell-dist.sh <shell checkout> [build|checksum] [user@phone]
#
# The shell repository (VoceOS/voce-shell) is private, so abuild cannot
# download the source. This makes voce-shell-<commit>.tar.gz from a local
# checkout at the commit pinned in aports/voce-shell/APKBUILD (_commit),
# copies it to ~/distfiles on the phone and the aport to ~/aports/voce-shell.
#   build     (default) build the package with abuild -d
#   checksum  after changing _commit: recompute sha512sums on the phone and
#             copy the APKBUILD back here
# git archive | gzip -n gives the same bytes again for the same commit.
set -e
SHELL_REPO=${1:?usage: $0 <shell checkout> [build|checksum] [user@phone]}
MODE=${2:-build}
PHONE=${3:-user@172.16.42.1}
TOP=$(cd "$(dirname "$0")/.." && pwd)
APORT=$TOP/aports/voce-shell
COMMIT=$(sed -n 's/^_commit=//p' "$APORT/APKBUILD")
TARBALL=voce-shell-$COMMIT.tar.gz
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -c safe.directory='*' -C "$SHELL_REPO" archive --format=tar \
	--prefix="voce-shell-$COMMIT/" "$COMMIT" | gzip -9n >"$TMP/$TARBALL"
echo "$TARBALL: $(wc -c <"$TMP/$TARBALL") bytes"

ssh -o BatchMode=yes "$PHONE" 'mkdir -p ~/distfiles ~/aports && rm -rf ~/aports/voce-shell'
scp -q "$TMP/$TARBALL" "$PHONE:distfiles/"
scp -q -r "$APORT" "$PHONE:aports/"

case "$MODE" in
checksum)
	ssh -o BatchMode=yes "$PHONE" 'cd ~/aports/voce-shell && SRCDEST=$HOME/distfiles abuild checksum'
	scp -q "$PHONE:aports/voce-shell/APKBUILD" "$APORT/APKBUILD"
	echo "sha512sums updated in $APORT/APKBUILD"
	;;
build)
	ssh -o BatchMode=yes "$PHONE" 'sh -s' <<'EOF'
set -e
cd ~/aports/voce-shell
export SRCDEST=$HOME/distfiles JOBS=$(nproc) MAKEFLAGS=-j$(nproc)
start=$(date +%s)
nice abuild -d >/tmp/voce-shell-abuild.log 2>&1 || { tail -40 /tmp/voce-shell-abuild.log; exit 1; }
echo "built in $(( $(date +%s) - start ))s"
ls ~/.local/share/abuild/aports/aarch64/ | grep '^voce-shell-'
EOF
	;;
*)
	echo "unknown mode: $MODE" >&2; exit 1 ;;
esac
