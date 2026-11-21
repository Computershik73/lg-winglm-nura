#!/bin/sh
# Install phoc r13 + phosh r20 + device r15, restart greetd with a ONE-SHOT autologin
# (initial_session is only read when greetd starts; the config is restored right after)
set -e
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE '(phosh|libphosh)(-lang|-schemas|-portalsconf|-dbg)?'); do pkgs="$pkgs $p=0.58.0-r20"; done
for p in $(apk info 2>/dev/null | grep -xE 'phoc(-lang|-dbg)?'); do pkgs="$pkgs $p=0.58.0-r13"; done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|ERROR|OK:' | tail -12
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r15.apk /tmp/device-lg-winglm-phosh-1-r15.apk 2>&1 | grep -E 'Upgrading|ERROR|OK:' | tail -3
gsettings get sm.puri.phosh.lockscreen force-portrait
C=/etc/phrog/greetd-config.toml
sudo cp $C /tmp/greetd-config.toml.before-autologin
sudo tee -a $C >/dev/null <<'EOF'

# TEMPORARY one-shot autologin for on-device tests (removed right after start)
[initial_session]
command = "/usr/bin/phosh-session"
user = "user"
EOF
sudo rc-service greetd restart >/dev/null 2>&1
sleep 20
sudo cp /tmp/greetd-config.toml.before-autologin $C
echo "greetd config restored: $(grep -c initial_session $C) initial_session lines active (comment only expected: $(grep -c '^\[initial_session\]' $C))"
pgrep -u user -x phosh >/dev/null && echo "phosh session up" || echo "phosh session NOT up"
pgrep -u user -x phoc >/dev/null && echo "phoc up"
