#!/bin/sh
for p in $(pgrep -u user -f 'sbin/winglm-swivel'); do kill $p; done
sleep 1
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') setsid winglm-swivel > /tmp/winglm-swivel.log 2>&1 < /dev/null &
sleep 6
ps -o pid,args | grep '[s]bin/winglm-swivel' | cut -c1-60
cat /tmp/winglm-swivel.log
echo "state=$(cat /sys/class/smartcover/swivel/state)"
env -i $(cat /tmp/phosh-user.env | tr '\n' ' ') wlr-randr | grep -E '^DSI|Enabled|Position|Scale|Transform'
