#!/bin/sh
# Test session with phosh under gdb (criticals fatal); switch the main screen (DSI-1) off and on
mkdir -p /home/user/.local/share/applications
cat > /tmp/phosh-gdb.sh <<'X'
#!/bin/sh
exec gdb -q -batch -ex 'set pagination off' -ex 'handle SIGPIPE SIGUSR1 SIGUSR2 nostop noprint' -ex run -ex 'bt 30' --args env G_DEBUG=fatal-criticals /usr/libexec/phosh > /tmp/phosh-gdb.log 2>&1
X
chmod 755 /tmp/phosh-gdb.sh
sed 's#^Exec=.*#Exec=/tmp/phosh-gdb.sh#' /usr/share/applications/mobi.phosh.Shell.desktop > /home/user/.local/share/applications/mobi.phosh.Shell.desktop
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
sudo rm -f /run/greetd.run; sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 40); do pgrep -u user -x phosh >/dev/null && break; sleep 1; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
rm -f /home/user/.local/share/applications/mobi.phosh.Shell.desktop
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
sleep 15
PP=$(pgrep -u user -x phosh); echo "phosh $PP"
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|LANG)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E wlr-randr | grep -E '^DSI|Enabled|Transform' | tr '\n' ' '; echo
$E wlr-randr --output DSI-1 --off; sleep 4; echo "after DSI-1 off: $(pgrep -u user -x phosh)"
$E wlr-randr --output DSI-1 --on; sleep 5; echo "after DSI-1 on: $(pgrep -u user -x phosh)"
grep -vE "^\[New Thread|^\[Thread|Reading symbols|^$|warning: (Unable|Could not)|Download|debuginfod|^\[Detaching|LWP" /tmp/phosh-gdb.log | grep -E "^#|CRITICAL|signal|exited" | head -30 | cut -c1-200
