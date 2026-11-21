#!/bin/sh
P=http://127.0.0.1:8888
mkdir -p /tmp/r0dbg && cd /tmp/r0dbg
[ -f phosh-dbg-0.58.0-r0.apk ] || env http_proxy=$P https_proxy=$P apk fetch --repository http://cdn.alpinelinux.org/edge/community phosh-dbg >/dev/null 2>&1
tar -xzf phosh-dbg-*.apk 2>/dev/null
DBG=$(find /tmp/r0dbg -name 'libphosh-0.45.so.0.debug' | head -1)
echo "dbg: $DBG"
apk info -e glib-dbg >/dev/null || sudo env http_proxy=$P https_proxy=$P apk add glib-dbg gtk+3.0-dbg >/dev/null 2>&1
chmod -R a+rX /tmp/r0dbg
cat > /tmp/phrog3.gdb <<EOF
set pagination off
set debug-file-directory /usr/lib/debug
run
info proc mappings
EOF
chmod 644 /tmp/phrog3.gdb
# 1st pass: crash + mappings to get the libphosh base
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') LD_LIBRARY_PATH=/tmp/r0/usr/lib gdb -q -batch -x /tmp/phrog3.gdb /usr/sbin/phrog > /tmp/phrog-gdb3.out 2>&1
base=$(grep '/tmp/r0/usr/lib/libphosh-0.45.so.0' /tmp/phrog-gdb3.out | head -1 | awk '{print $1}')
echo "base: $base"
# 2nd pass: load symbols at that base (no ASLR in gdb, same layout)
cat > /tmp/phrog4.gdb <<EOF
set pagination off
set debug-file-directory /usr/lib/debug
run
add-symbol-file $DBG -o $base
bt 25
EOF
chmod 644 /tmp/phrog4.gdb
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') LD_LIBRARY_PATH=/tmp/r0/usr/lib gdb -q -batch -x /tmp/phrog4.gdb /usr/sbin/phrog 2>&1 \
  | grep -E '^#[0-9]|SIGSEGV|^add symbol' | cut -c1-230
