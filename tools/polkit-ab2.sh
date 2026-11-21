#!/bin/sh
PP=$(pgrep -u user -x phosh | head -1)
chk() { pkcheck --action-id org.freedesktop.NetworkManager.network-control --process $PP >/dev/null 2>/tmp/pk.err && echo "  -> OK" || echo "  -> $(cat /tmp/pk.err | sed 's/.*Failed: //')"; }
echo "D: started as root (drops privileges itself)"
sudo sh -c "setsid /usr/lib/polkit-1/polkitd --no-debug --replace > /tmp/pk-D.log 2>&1 < /dev/null &"; sleep 3; chk
P=$(pgrep -x polkitd); echo "  pid $P uid $(awk '/^Uid/{print $2}' /proc/$P/status), fdinfo owner: $(sudo stat -c %U /proc/$P/fdinfo)"
echo "E: OpenRC with command_user=polkitd"
printf 'command_user="polkitd:polkitd"\n' | sudo tee /etc/conf.d/polkit >/dev/null
sudo pkill -x polkitd; sleep 1
sudo rc-service polkit start 2>&1 | tail -1; sleep 3; chk
P=$(pgrep -x polkitd); echo "  pid $P uid $(awk '/^Uid/{print $2}' /proc/$P/status), fdinfo owner: $(sudo stat -c %U /proc/$P/fdinfo)"
