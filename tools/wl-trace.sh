#!/bin/sh
# Start phrog with client-side WAYLAND_DEBUG via a temporary /usr/local/bin/phrog wrapper,
# then open the swivel and capture the shield's protocol traffic.
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
sudo tee /usr/local/bin/phrog >/dev/null <<'EOF'
#!/bin/sh
# TEMPORARY debug wrapper (remove after the keypad investigation)
WAYLAND_DEBUG=client exec /usr/bin/phrog "$@" 2>>/tmp/phrog-wl.log
EOF
sudo chmod 755 /usr/local/bin/phrog
sudo rm -f /tmp/phrog-wl.log
sudo rc-service greetd restart >/dev/null 2>&1
sleep 25
pgrep -x phrog >/dev/null && echo "phrog up" || echo "phrog not running"
real=$(cat $STATE)
L0=$(sudo wc -l < /tmp/phrog-wl.log)
echo "lines before swivel: $L0"
echo 2 | sudo tee $INJ >/dev/null
sleep 8
sudo env $G grim -o DSI-2 -s 0.35 /tmp/gr-wl.png
L1=$(sudo wc -l < /tmp/phrog-wl.log)
echo "lines after swivel: $L1"
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
sudo cp /tmp/phrog-wl.log /tmp/phrog-wl-copy.log
sudo chmod 644 /tmp/phrog-wl-copy.log
echo "$L0" > /tmp/phrog-wl-mark
