#!/bin/sh
# usage: sh -s LOGFILE CMD...   start CMD inside the graphical session's cgroup (as if launched from phosh)
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
LOG=$1; shift
PP=$(pgrep -u user -x phosh | head -1)
CG=$(awk -F: '$1=="0" {print $3}' /proc/$PP/cgroup | head -1)
$E setsid sh -c 'echo $$ > /tmp/insession.pid; sleep 1; exec "$@"' sh "$@" > "$LOG" 2>&1 < /dev/null &
sleep 0.3
echo "$(cat /tmp/insession.pid)" | sudo tee /sys/fs/cgroup$CG/cgroup.procs >/dev/null && echo "started $1 in $CG"
