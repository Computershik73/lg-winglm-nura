#!/bin/sh
C=/etc/phrog/greetd-config.toml; B=/var/lib/winglm-greetd-config.toml.before-autologin
for i in $(seq 1 40); do pgrep -u user -x phosh >/dev/null && break; sleep 2; done
[ -f $B ] && sudo cp $B $C && sudo rm -f $B
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
PP=$(pgrep -u user -x phosh | head -1); echo "phosh: $PP ($(apk info -v 2>/dev/null | grep '^phosh-0'))"
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep 20
echo "== polkitd: $(ps -o pid,user,args | grep '[p]olkitd' | head -1) env-dbus-activated: $(sudo cat /proc/$(pgrep -x polkitd)/environ | tr '\0' '\n' | grep -c DBUS_STARTER)"
pkcheck --action-id org.freedesktop.NetworkManager.network-control --process $PP && echo "  phosh authorized"
echo "== NM agent: $(sudo logread | grep -c 'mobi.phosh.Shell.NetworkAgent.*registered') (log may have rotated); nmcli perms: $($E nmcli -t general permissions | grep network-control)"
echo "== OSK: $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia')"
echo "== speaker: $(amixer -c 0 cget name='PRIM_MI2S_RX Channels' | grep ': values')"
echo "== BT: $(sudo tail -2 /var/log/winglm-bt.log | tr "
" " ")"; bluetoothctl show | grep -E "Powered"; timeout 10 bluetoothctl --timeout 7 scan on 2>/dev/null | grep -c Device
echo "== wlan/modem: $(ip -br link show wlan0 | cut -c1-40) $(mmcli -L 2>&1 | head -1)"
echo "== phosh still: $(pgrep -u user -x phosh)  swivel: $(cat /sys/class/smartcover/swivel/state)"
