pids=""
for p in /proc/[0-9]*; do
	ls -l "$p/fd" 2>/dev/null | grep -q ttyGS0 && pids="$pids ${p#/proc/}"
done
echo "holding ttyGS0:$pids"
for p in $pids; do echo "  $p: $(tr '\0' ' ' < /proc/$p/cmdline)"; done
kill -9 $pids 2>/dev/null
sleep 1
left=""
for p in /proc/[0-9]*; do ls -l "$p/fd" 2>/dev/null | grep -q ttyGS0 && left="$left ${p#/proc/}"; done
echo "left:$left"
[ -z "$left" ] && touch /tmp/continue_boot && echo CONTINUING
