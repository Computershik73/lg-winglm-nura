#!/bin/sh
DBG=$(find /usr/lib/debug -name 'libphosh-0.45.so.0.debug' | head -1)
echo "debug file: $DBG"
cat > /tmp/phrog.gdb <<'EOF'
set pagination off
run
bt 6
info proc mappings
EOF
chmod 644 /tmp/phrog.gdb
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') gdb -q -batch -x /tmp/phrog.gdb /usr/sbin/phrog > /tmp/phrog-gdb.out 2>&1
grep -E '^#[0-9]' /tmp/phrog-gdb.out | head -6
base=$(grep 'libphosh-0.45.so.0' /tmp/phrog-gdb.out | awk '$5 == "0x0" || $4 == "0x0" {print $1; exit}')
[ -n "$base" ] || base=$(grep 'libphosh-0.45.so.0' /tmp/phrog-gdb.out | head -1 | awk '{print $1}')
echo "libphosh base: $base"
for pc in $(grep -E '^#[0-9]+ .* in .* (from|at) /lib/libphosh' /tmp/phrog-gdb.out | awk '{print $2}'); do
	off=$(printf '0x%x' $(( pc - base )))
	echo "== $pc -> $off"
	addr2line -f -i -C -e "$DBG" "$off" 2>&1 | head -6
done
