#!/bin/sh
set -e
cd /tmp
echo "== device package"
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r6.apk 2>&1 | grep -vE '^\s*$' | tail -4
ls -la /usr/lib/udev/rules.d/90-winglm-touch.rules
echo "== mesa system integration"
sudo sh /tmp/mesa-kgsl-system.sh
echo "== phoc.ini (both outputs)"
for f in /etc/phosh/phoc.ini /etc/phrog/phoc.ini; do
	sudo cp -n "$f" "$f.single-screen" 2>/dev/null || true
	sudo tee "$f" >/dev/null <<'EOF'
[core]
xwayland=false

[output:DSI-1]
scale = 3

[output:DSI-2]
scale = 3

[output:Virtual-1]
enable = false
EOF
done
cat /etc/phosh/phoc.ini
echo "== quick GL check without env"
pkill -x sway-nocap 2>/dev/null || true
sleep 1
