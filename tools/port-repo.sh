#!/bin/bash
# one git repo for the whole LG Wing port: pmaports packages, the Alpine
# package forks built on the phone, and the tools/prototypes
set -e
SP=$HOME/lg-wing-port/tools
W=$HOME/lg-wing-port/pmaports
PMA=$HOME/.local/var/pmbootstrap/cache_git/pmaports
R=$HOME/lg-wing-port

# leave pmbootstrap's clone as it was (untracked files, branch main)
cd $PMA
git reset -q
git switch -q main
git branch -D lg-winglm >/dev/null
git config --unset user.name || true
git config --unset user.email || true
echo "pmaports clone: $(git branch --show-current), $(git status --short | wc -l) untracked entries"

mkdir -p $R && cd $R
[ -d .git ] || git init -q -b main
git config user.name Computershik73
git config user.email il.mohoff2016@yandex.ru

# 1. pmaports packages (the scratch copy is the editing source)
mkdir -p pmaports/device/testing pmaports/temp
rsync -a --delete $W/device/testing/device-lg-winglm/ pmaports/device/testing/device-lg-winglm/
rsync -a --delete $W/device/testing/linux-lg-winglm/ pmaports/device/testing/linux-lg-winglm/
rsync -a --delete $PMA/temp/phosh/ pmaports/temp/phosh/

# 2. Alpine package forks built natively on the phone (~/aports, no src/pkg)
mkdir -p aports
ssh -o BatchMode=yes user@172.16.42.1 'cd ~/aports && tar cf - --exclude=src --exclude=pkg --exclude="*.tar.*" --exclude="*.apk" .' | tar xf - -C aports

# 3. tools and prototypes from the session scratchpad (no captures/dumps)
mkdir -p tools
rsync -a --delete --prune-empty-dirs \
	--include='*/' --include='*.py' --include='*.sh' --include='*.ps1' --include='*.diff' \
	--exclude='re/***' --exclude='frames/***' --exclude='shots/***' --exclude='ksrc/***' \
	--exclude='__pycache__/***' --exclude='*' \
	$SP/ tools/

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
*.apk
*.bin
EOF
[ -f README.md ] || cat > README.md <<'EOF'
# LG Wing (LM-F100N, "winglm") postmarketOS port

- `pmaports/` - postmarketOS packages: `device/testing/device-lg-winglm`
  (device package and subpackages: phosh, dsp, volte, ...),
  `device/testing/linux-lg-winglm` (kernel), `temp/phosh`.
  Build: copy into pmbootstrap's pmaports, `pmbootstrap build device-lg-winglm`.
- `aports/` - Alpine package forks with Wing patches (phosh, phoc, stevia,
  glib, callaudiod, qrtr, qrtr-ns, pd-mapper, tqftpserv); built natively on
  the phone with abuild (`~/aports/<pkg>` there).
- `tools/` - bring-up scripts and prototypes (QMI/IMS/VoLTE, diag, ACDB,
  ...), run from WSL against the phone over USB networking.
EOF
git add -A
if git diff --cached --quiet; then echo "nothing new"; else
	git commit -q -F - <<'EOF'
LG Wing port: device and kernel packages, Alpine forks, tools

State at device-lg-winglm r31: VoLTE with media in the modem (LG MMPF
over QMI 703), earpiece Class-H fix in UCM, IPA mobile data, VSS SIM
init, DSP/modem/WLAN/BT bring-up, Phosh two-screen support.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
fi
git log --oneline | head -3
echo "files: $(git ls-files | wc -l), size: $(du -sh --exclude=.git . | cut -f1)"
git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -20
