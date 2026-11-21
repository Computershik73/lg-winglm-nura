#!/bin/sh
cat > /tmp/phrog2.gdb <<'EOF'
set pagination off
set breakpoint pending on
break g_error_free
commands
silent
printf "g_error_free(%p) code=%d msg=", $x0, *(int *)($x0+4)
x/s *(char **)($x0+8)
bt 3
continue
end
run
bt 6
EOF
chmod 644 /tmp/phrog2.gdb
sudo -u greetd env -i $(cat /tmp/phrog.env | tr '\n' ' ') gdb -q -batch -x /tmp/phrog2.gdb /usr/sbin/phrog > /tmp/phrog-gdb2.out 2>&1
grep -E 'g_error_free\(|^0x|^#[0-9]|SIGSEGV' /tmp/phrog-gdb2.out | grep -vE '^\[' | tail -40 | cut -c1-200
