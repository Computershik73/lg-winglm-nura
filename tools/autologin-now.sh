#!/bin/sh
# one-shot autologin without a reboot: greetd runs [initial_session] when it starts
C=/etc/phrog/greetd-config.toml; B=/var/lib/winglm-greetd-config.toml.before-autologin
ls /etc/init.d/ | grep -i greet
printf '#!/bin/sh\nexec /usr/bin/phosh-session > /tmp/sess.log 2>&1\n' | sudo tee /usr/local/bin/winglm-logged-session >/dev/null
sudo chmod 755 /usr/local/bin/winglm-logged-session
grep -q '^\[initial_session\]' $C || {
	sudo cp $C $B
	printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after login)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
}
ls -la /run/greetd* 2>&1; sudo rm -f /run/greetd.run
sudo rc-service greetd restart 2>&1 | tail -2
for i in $(seq 1 40); do pgrep -u user -x phosh >/dev/null && break; sleep 1; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
sudo rm -f /usr/local/bin/winglm-logged-session
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
echo "phosh: $(pgrep -u user -x phosh) calls: $(pgrep -a -u user -x gnome-calls) callaudiod: $(pgrep -a -u user -x callaudiod)"
