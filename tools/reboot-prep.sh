#!/bin/sh
# Install phosh r21, arm a one-shot autologin for the next greetd start, reboot
set -e
R=/home/user/.local/share/abuild/aports
pkgs=$(apk info 2>/dev/null | grep -E '^(phosh|libphosh)' | sort -u | tr '\n' ' ')
sudo apk add --no-network --repository "$R" -u $pkgs 2>&1 | grep -vE '^\s*$' | tail -3
apk info -v 2>/dev/null | grep -E '^phosh-0'
C=/etc/phrog/greetd-config.toml
grep -q '^\[initial_session\]' $C || {
	sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
	printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after boot)\n[initial_session]\ncommand = "/usr/bin/phosh-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
}
echo "autologin armed: $(grep -c '^\[initial_session\]' $C)"
sync
sudo reboot
