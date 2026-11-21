#!/bin/sh
# After the reboot: drop the autologin, check the call stack and the earpiece level
C=/etc/phrog/greetd-config.toml; B=/var/lib/winglm-greetd-config.toml.before-autologin
for i in $(seq 1 60); do pgrep -u user -x phosh >/dev/null && break; sleep 2; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
PP=$(pgrep -n -u user -x phosh)
sudo cat /proc/$PP/environ | tr '\0' '\n' | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep 25
echo "phosh $PP still: $(pgrep -n -u user -x phosh)"
echo "q6voiced: $(pgrep -a q6voiced | cut -c1-60)"
echo "calls daemon: $(pgrep -a -u user -f 'gnome-calls|/usr/bin/gnome-calls|calls --daemon' | head -1 | cut -c1-70)"
echo "callaudiod pkg: $(apk info -v 2>/dev/null | grep '^callaudiod-0')"
R="/sys/kernel/debug/regmap/soc:qcom,msm-audio-apr:qcom,q6core-audio:bolero-cdc"
echo "RX0 vol reg: $(sudo grep -E '^1414:' "$R/registers")"
echo "profiles with Voice Call: $($E pactl list cards | grep -c 'Voice Call (')"
echo "modem: $(mmcli -L 2>&1 | head -1)"
echo "BT: $(bluetoothctl show | grep -o 'Powered: ..*')"
