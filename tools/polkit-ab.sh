#!/bin/sh
# Which polkitd launch variant can resolve session processes?
PP=$(pgrep -u user -x phosh | head -1)
chk() { pkcheck --action-id org.freedesktop.NetworkManager.network-control --process $PP >/dev/null 2>/tmp/pk.err && echo "  -> OK" || echo "  -> $(cat /tmp/pk.err | sed 's/.*Failed: //')"; }
echo "A: current (dbus-activated)"; chk
echo "B: su polkitd, --no-debug, env -i"
sudo sh -c "setsid su -s /bin/sh polkitd -c 'env -i /usr/lib/polkit-1/polkitd --no-debug --replace' > /tmp/pk-B.log 2>&1 < /dev/null &"; sleep 3; chk
echo "C: su polkitd, debug"
sudo sh -c "G_MESSAGES_DEBUG=all setsid su -s /bin/sh polkitd -c '/usr/lib/polkit-1/polkitd --replace' > /tmp/pk-C.log 2>&1 < /dev/null &"; sleep 3; chk
grep -iE "pidfd|not found|subject|error" /tmp/pk-C.log | tail -5 | cut -c1-200
cat /proc/$(pgrep -x polkitd)/cgroup
