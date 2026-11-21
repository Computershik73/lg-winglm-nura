#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
P=$(pgrep -x phrog | head -1)
real=$(cat $STATE)
echo 2 | sudo tee $INJ >/dev/null
sleep 6
S=$(grep -oE 'shield 0x[0-9a-f]+ on DSI-2' /tmp/phrog-session.log | tail -1 | awk '{print $2}')
echo "shield=$S"
cat > /tmp/kp3.gdb <<EOF
set pagination off
set confirm off
set \$w = (void *) $S
printf "shield mapped=%d visible=%d alloc=%dx%d\n", (int) gtk_widget_get_mapped (\$w), (int) gtk_widget_get_visible (\$w), (int) gtk_widget_get_allocated_width (\$w), (int) gtk_widget_get_allocated_height (\$w)
set \$box = (void *) gtk_bin_get_child (\$w)
printf "box=%p mapped=%d visible=%d child_visible=%d alloc=%dx%d\n", \$box, (int) gtk_widget_get_mapped (\$box), (int) gtk_widget_get_visible (\$box), (int) gtk_widget_get_child_visible (\$box), (int) gtk_widget_get_allocated_width (\$box), (int) gtk_widget_get_allocated_height (\$box)
set \$l = (void **) gtk_container_get_children (\$box)
printf "children list=%p\n", \$l
set \$c1 = \$l ? \$l[0] : 0
printf "child1=%p mapped=%d visible=%d child_visible=%d alloc=%dx%d\n", \$c1, (int) gtk_widget_get_mapped (\$c1), (int) gtk_widget_get_visible (\$c1), (int) gtk_widget_get_child_visible (\$c1), (int) gtk_widget_get_allocated_width (\$c1), (int) gtk_widget_get_allocated_height (\$c1)
set \$n = (void **) \$l[1]
set \$c2 = \$n ? \$n[0] : 0
printf "child2=%p mapped=%d visible=%d alloc=%dx%d\n", \$c2, (int) gtk_widget_get_mapped (\$c2), (int) gtk_widget_get_visible (\$c2), (int) gtk_widget_get_allocated_width (\$c2), (int) gtk_widget_get_allocated_height (\$c2)
printf "box preferred: "
set \$minh = 0
detach
quit
EOF
chmod 644 /tmp/kp3.gdb
sudo gdb -q -batch -p "$P" -x /tmp/kp3.gdb 2>&1 | grep -E '^(shield|box|children|child)'
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
pgrep -x phrog >/dev/null && echo "phrog alive" || echo "phrog DEAD"
