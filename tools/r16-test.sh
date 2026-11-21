#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
# greeter session that logs to a file
sudo tee /usr/local/bin/phrog-debug-session >/dev/null <<'EOF'
#!/bin/sh
PHOC_INI=/etc/phrog/phoc.ini
export XDG_CURRENT_DESKTOP=Phrog:Phosh:GNOME
export GNOME_SESSION_AUTOSTART_DIR=/usr/share/phrog/autostart:/etc/phrog/autostart
exec > /tmp/phrog-session.log 2>&1
exec dbus-run-session phoc -S -C "${PHOC_INI}" -E 'gnome-session --session=phrog'
EOF
sudo chmod 755 /usr/local/bin/phrog-debug-session
sudo sed -i 's|^command = "/usr/libexec/phrog-greetd-session"|command = "/usr/local/bin/phrog-debug-session"|' /etc/phrog/greetd-config.toml
real=$(cat $STATE)
sudo rm -f /tmp/phrog-session.log
sudo rc-service greetd restart >/dev/null 2>&1
sleep 20
pgrep -x phrog >/dev/null && echo "phrog up" || echo "phrog NOT up"
echo 2 | sudo tee $INJ >/dev/null
sleep 8
sudo env $G grim -o DSI-2 -s 0.35 /tmp/r16-DSI-2.png && echo "shot DSI-2"
grep -E 'Keypad moves|swivel|DSI-1 transform' /tmp/phrog-session.log | tail -8
echo "$real" | sudo tee $INJ >/dev/null
sleep 3
echo "state back to $(cat $STATE)"
grep -E 'Keypad moves' /tmp/phrog-session.log | tail -3
pgrep -x phrog >/dev/null && echo "phrog alive" || echo "phrog DEAD"
