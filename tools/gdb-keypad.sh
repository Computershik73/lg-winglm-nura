#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
P=$(pgrep -x phrog | head -1)
[ -n "$P" ] || { echo "no phrog"; exit 1; }
real=$(cat $STATE)
cat > /tmp/kp2.gdb <<'EOF'
set pagination off
set confirm off
handle SIG32 nostop noprint pass
handle SIG33 nostop noprint pass
handle SIGPIPE nostop noprint pass
break apply_keypad_placement
commands
silent
set $ls = self
printf "apply_keypad_placement ls=%p\n", self
continue
end
continue
printf "---- after interrupt\n"
set $p = (PhoshLockscreenPrivate *) ((char *) $ls + PhoshLockscreen_private_offset)
printf "keypad_external=%d container=%p parent=%p\n", $p->keypad_external, $p->keypad_container, gtk_widget_get_parent ($p->keypad)
printf "keypad visible=%d child_visible=%d mapped=%d realized=%d alloc=%dx%d\n", (int) gtk_widget_get_visible ($p->keypad), (int) gtk_widget_get_child_visible ($p->keypad), (int) gtk_widget_get_mapped ($p->keypad), (int) gtk_widget_get_realized ($p->keypad), (int) gtk_widget_get_allocated_width ($p->keypad), (int) gtk_widget_get_allocated_height ($p->keypad)
printf "box visible=%d child_visible=%d mapped=%d alloc=%dx%d\n", (int) gtk_widget_get_visible ($p->keypad_container), (int) gtk_widget_get_child_visible ($p->keypad_container), (int) gtk_widget_get_mapped ($p->keypad_container), (int) gtk_widget_get_allocated_width ($p->keypad_container), (int) gtk_widget_get_allocated_height ($p->keypad_container)
set $top = gtk_widget_get_toplevel ($p->keypad_container)
printf "shield %p mapped=%d alloc=%dx%d\n", $top, (int) gtk_widget_get_mapped ($top), (int) gtk_widget_get_allocated_width ($top), (int) gtk_widget_get_allocated_height ($top)
detach
quit
EOF
chmod 644 /tmp/kp2.gdb
sudo rm -f /tmp/kp2.log
sudo setsid gdb -q -batch -p "$P" -x /tmp/kp2.gdb > /tmp/kp2.log 2>&1 < /dev/null &
sleep 10
echo 2 | sudo tee $INJ >/dev/null
sleep 10
G=$(pgrep -f 'gdb -q -batch -p' | head -1)
sudo kill -INT "$G"
sleep 5
grep -vE '^\[(New|Thread|LWP)|^$' /tmp/kp2.log | grep -vE 'auto-load|syscall_cp|warning:' | tail -15
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
pgrep -x phrog >/dev/null && echo "phrog alive" || echo "phrog DEAD"
