#!/bin/sh
# Restart winglm-swivel in the session, then stop stevia cleanly and wait for the watchdog to bring it back
for p in $(pgrep -u user -x winglm-swivel); do kill $p; done
sleep 1
sh /tmp/insession.sh /tmp/winglm-swivel.log winglm-swivel
sleep 4
echo "swivel: $(pgrep -u user -x winglm-swivel)"
OLD=$(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1)
echo "stevia before: $OLD"; kill $OLD
for i in $(seq 1 25); do
	sleep 1
	NEW=$(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1)
	[ -n "$NEW" ] && break
done
echo "stevia after ${i}s: $NEW"
cat /tmp/winglm-swivel.log
ls -la /home/user/.cache/winglm/ 2>&1 | tail -2
