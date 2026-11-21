#!/bin/sh
# Run stevia under gdb inside the session cgroup to get the crash backtrace
R=/home/user/.local/share/abuild/aports
sudo apk add --no-network --repository "$R" stevia-dbg=0.58.0-r14 2>&1 | tail -1
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
PP=$(pgrep -u user -x phosh | head -1)
CG=$(sed -n 's/^0:://p' /proc/$PP/cgroup)
for p in $(pgrep -u user -f 'phosh-osk-stevia'); do kill $p; done
sleep 1
cat > /tmp/stv.gdb <<'EOF'
set pagination off
set confirm off
handle SIGPIPE nostop noprint pass
handle SIG32 nostop noprint pass
handle SIG33 nostop noprint pass
run
bt 25
info registers pc
quit
EOF
$E setsid sh -c 'echo $$ > /tmp/stevia-wrap.pid; sleep 1; exec gdb -q -batch -x /tmp/stv.gdb --args /usr/bin/phosh-osk-stevia --allow-replacement' > /tmp/stevia-gdb.log 2>&1 < /dev/null &
sleep 0.3
echo "$(cat /tmp/stevia-wrap.pid)" | sudo tee /sys/fs/cgroup$CG/cgroup.procs >/dev/null
sleep 25
grep -vE '^\[(New|Thread)|^$|glycin|Glycin|auto-load|warning: ' /tmp/stevia-gdb.log | grep -A30 -E 'SIGSEGV|signal|#0' | head -40 | cut -c1-200
