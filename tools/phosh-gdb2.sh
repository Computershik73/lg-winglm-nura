#!/bin/sh
cat > /tmp/phosh.gdb <<'G'
set pagination off
set breakpoint pending on
handle SIGPIPE SIGUSR1 SIGUSR2 nostop noprint
break g_return_if_fail_warning
commands
silent
printf "=== critical in %s\n", pretty_function
bt 12
continue
end
run
bt 20
G
cat > /tmp/phosh-gdb.sh <<'X'
#!/bin/sh
exec gdb -q -batch -x /tmp/phosh.gdb --args /usr/libexec/phosh > /tmp/phosh-gdb.log 2>&1
X
chmod 755 /tmp/phosh-gdb.sh
