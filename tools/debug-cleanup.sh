#!/bin/sh
# Undo the keypad-investigation debugging: phrog WAYLAND_DEBUG wrapper and the logging greeter session
set -e
echo "== wrapper"
head -3 /usr/local/bin/phrog 2>/dev/null || true
if grep -q 'TEMPORARY debug wrapper' /usr/local/bin/phrog 2>/dev/null; then
	sudo rm /usr/local/bin/phrog
	echo "removed /usr/local/bin/phrog"
fi
echo "== greetd config"
ls -la /etc/phrog/greetd-config.toml /etc/phrog/greetd-config.toml.orig
diff /etc/phrog/greetd-config.toml.orig /etc/phrog/greetd-config.toml || true
sudo cp /etc/phrog/greetd-config.toml.orig /etc/phrog/greetd-config.toml
sudo rm -f /usr/local/bin/phrog-debug-session
grep -n 'command' /etc/phrog/greetd-config.toml
sudo rc-service greetd restart >/dev/null 2>&1
sleep 20
pgrep -a phrog | head -2
pgrep -af phoc | grep -v pgrep | head -2
sudo rm -f /tmp/phrog-wl.log /tmp/phrog-wl-copy.log /tmp/kp*.gdb
