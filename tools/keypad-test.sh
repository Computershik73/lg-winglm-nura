#!/bin/sh
# Drive the swivel in software and watch where the keypad goes (greeter).
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"

if [ "$1" = setup ]; then
	sudo mkdir -p /usr/local/share/applications
	sudo tee /usr/local/share/applications/mobi.phosh.Phrog.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Phrog
Comment=Greeter shell for greetd (debug wrapper)
Type=Application
Exec=sh -c 'G_MESSAGES_DEBUG=phosh-lockscreen-manager,phosh-lockscreen,phosh-lockshield exec phrog > /tmp/phrog-debug.log 2>&1'
NoDisplay=true
EOF
	sudo rm -f /tmp/phrog-debug.log
	sudo rc-service greetd restart >/dev/null 2>&1
	sleep 20
	pgrep -f '^/usr/sbin/phrog|exec phrog' >/dev/null && echo "phrog up" || echo "phrog NOT up"
	exit 0
fi

shot() {
	sudo env $G grim -o "$1" -s 0.3 "/tmp/kp-$2-$1.png" 2>/dev/null && echo "shot $2 $1"
}

for step in 2 1 2; do
	echo "== inject $step"
	echo $step | sudo tee $INJ >/dev/null
	sleep 6
	echo "state=$(cat $STATE)"
	sudo env $G wlr-randr | grep -E '^DSI|Enabled|Transform'
	for o in DSI-1 DSI-2; do shot $o $step; done
done
echo "== phrog debug"
grep -E 'Keypad|keypad|shield|Shield|Monitor' /tmp/phrog-debug.log | tail -20 | cut -c1-160
pgrep -f '^/usr/sbin/phrog|exec phrog' >/dev/null && echo "phrog alive" || echo "phrog DEAD"
