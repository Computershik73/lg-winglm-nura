#!/bin/sh
GS=$(pgrep -f 'gnome-session-binary --session=phrog' | head -1)
sudo cat /proc/$GS/environ | tr '\0' '\n' | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP)=' > /tmp/phrog.env
echo "== plain run with debug"
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') G_MESSAGES_DEBUG=phosh-lockscreen-manager,phosh-lockscreen,phosh-lockshield \
	timeout 15 /usr/sbin/phrog > /tmp/phrog-crash.log 2>&1
echo "rc=$?"
grep -vE 'faccessat|swcatalog|metainfo|Glycin|background image|handle position|polkit' /tmp/phrog-crash.log | tail -15 | cut -c1-200
echo "== gdb"
cat > /tmp/phrog-crash.gdb <<'EOF'
set pagination off
run
bt 15
EOF
chmod 644 /tmp/phrog-crash.gdb
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') gdb -q -batch -x /tmp/phrog-crash.gdb /usr/sbin/phrog 2>&1 \
	| grep -E '^#[0-9]|SIGSEGV|SIGABRT|SIGTRAP|exited' | cut -c1-200 | head -20
