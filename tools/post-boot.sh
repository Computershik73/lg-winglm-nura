#!/bin/sh
# After the reboot: drop the one-shot autologin, then check polkit / NM agent / OSK / speaker
C=/etc/phrog/greetd-config.toml
B=/var/lib/winglm-greetd-config.toml.before-autologin
for i in $(seq 1 40); do pgrep -u user -x phosh >/dev/null && break; sleep 2; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
PP=$(pgrep -u user -x phosh | head -1); echo "phosh: $PP"
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep 15
echo "== boot order"; for s in elogind polkit networkmanager modemmanager; do printf '%-15s pid %s\n' $s "$(pgrep -o -f "$(case $s in elogind) echo elogind/elogind;; polkit) echo polkitd;; networkmanager) echo '^NetworkManager';; modemmanager) echo ModemManager;; esac)")"; done
echo "== polkit"; pkcheck --action-id org.freedesktop.NetworkManager.network-control --process $PP && echo "phosh authorized"
echo "== osk: $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia') owner: $($E busctl --user status sm.puri.OSK0 2>/dev/null | grep -m1 '^PID=')"
echo "== speaker: $(amixer -c 0 cget name='PRIM_MI2S_RX Channels' | grep ': values')"
echo "== keyring: $(pgrep -a -u user gnome-keyring | tr '\n' ' ')"
echo "== swivel: $(cat /sys/class/smartcover/swivel/state)"; $E wlr-randr | grep -E '^DSI|Enabled|Transform' | tr '\n' ' '; echo
