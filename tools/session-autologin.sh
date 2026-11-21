#!/bin/sh
# One-shot autologin into a session without a reboot, for remote tests:
#   ssh user@172.16.42.1 'sh -s voce'  < tools/session-autologin.sh
#   ssh user@172.16.42.1 'sh -s phosh' < tools/session-autologin.sh
# greetd runs [initial_session] when it starts; it is added to the phrog
# greetd config, greetd is restarted (this ends the running session) and the
# config is restored right after the login. If the session fails, greetd
# falls back to the phrog greeter.
S=${1:-phosh}
case "$S" in
voce)  CMD=/usr/bin/voce-shell-session; PROC=wayland-mobile-shell ;;
phosh) CMD=/usr/bin/phosh-session;      PROC=phosh ;;
*) echo "usage: sh -s voce|phosh" >&2; exit 1 ;;
esac
C=/etc/phrog/greetd-config.toml; B=/var/lib/winglm-greetd-config.toml.before-autologin
W=/usr/local/bin/winglm-logged-session
printf '#!/bin/sh\nexec %s\n' "$CMD" | sudo tee $W >/dev/null
sudo chmod 755 $W
grep -q '^\[initial_session\]' $C || {
	sudo cp $C $B
	printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after login)\n[initial_session]\ncommand = "%s"\nuser = "user"\n' $W | sudo tee -a $C >/dev/null
}
sudo rm -f /run/greetd.run
sudo rc-service greetd restart 2>&1 | tail -1
for i in $(seq 1 40); do pidof $PROC >/dev/null && break; sleep 1; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
sudo rm -f $W
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
echo "$S: $(pidof $PROC || echo NOT running)"
