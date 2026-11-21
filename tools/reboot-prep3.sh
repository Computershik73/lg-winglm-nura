#!/bin/sh
printf '#!/bin/sh\nexec /usr/bin/phosh-session > /tmp/sess.log 2>&1\n' | sudo tee /usr/local/bin/winglm-logged-session >/dev/null
sudo chmod 755 /usr/local/bin/winglm-logged-session
sudo rm -f /run/msm-firmware-loader/target/modem_pr
C=/etc/phrog/greetd-config.toml
grep -q '^\[initial_session\]' $C || {
	sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
	printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after boot)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
}
echo "autologin armed: $(grep -c '^\[initial_session\]' $C)"
sync; sudo reboot
