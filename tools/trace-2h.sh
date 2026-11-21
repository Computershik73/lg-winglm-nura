#!/bin/sh
# what happened at the 2-hour marks and at the 20:18 traceback
cd /var/log
for f in winglm-volte.trace*; do echo "== $f $(sudo wc -l < $f) lines"; done
for f in winglm-volte.trace*; do
	sudo grep -naE "link down|re-challenged|Traceback|error handling|TypeError|line [0-9]+, in" $f | head -20 | sed "s|^|$f:|" | cut -c1-220
done
echo "===== context before the first 'link down'"
for f in winglm-volte.trace*; do
	n=$(sudo grep -naE "link down: initial REGISTER" $f | head -1 | cut -d: -f1)
	[ -n "$n" ] || continue
	echo "--- $f line $n"
	sudo sed -n "$((n-28)),$((n+3))p" $f | grep -av "GNOME Calls REGISTER" | cut -c1-230
	break
done
echo "===== traceback"
for f in winglm-volte.trace*; do
	n=$(sudo grep -naE "error handling message" $f | head -1 | cut -d: -f1)
	[ -n "$n" ] || continue
	sudo sed -n "$((n-6)),$((n+14))p" $f | cut -c1-230
	break
done
