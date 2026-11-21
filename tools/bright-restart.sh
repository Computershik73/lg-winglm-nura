#!/bin/sh
PH=$(pgrep -u user -x phosh | head -1)
CG=$(sed -n 's/^0:://p' /proc/$PH/cgroup)
echo "phosh cgroup: $CG"
pkill -u user -f 'winglm-brightness --daemon' 2>/dev/null || true
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') setsid sh -c 'sleep 2; exec winglm-brightness --daemon' > /tmp/winglm-brightness.log 2>&1 < /dev/null &
sleep 0.5
W=$(pgrep -u user -f "sleep 2; exec winglm-brightness" | head -1)
echo "$W" | sudo tee /sys/fs/cgroup$CG/cgroup.procs > /dev/null && echo "moved $W"
sleep 4
D=$(pgrep -u user -f 'winglm-brightness --daemon' | head -1)
echo "daemon $D in $(cat /proc/$D/cgroup)"
for b in panel0-backlight panel1-backlight; do echo "$b $(cat /sys/class/backlight/$b/brightness)"; done
cat /tmp/winglm-brightness.log
