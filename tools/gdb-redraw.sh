#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
P=$(pgrep -x phrog | head -1)
real=$(cat $STATE)
echo 2 | sudo tee $INJ >/dev/null
sleep 6
sudo env $G grim -o DSI-2 -s 0.35 /tmp/gr-before.png
S=$(grep -oE 'shield 0x[0-9a-f]+ on DSI-2' /tmp/phrog-session.log | tail -1 | awk '{print $2}')
echo "shield=$S"
cat > /tmp/kp4.gdb <<EOF
set pagination off
set confirm off
set \$w = (void *) $S
set \$gw = (void *) gtk_widget_get_window (\$w)
set \$fc = (void *) gdk_window_get_frame_clock (\$gw)
printf "gdkwindow=%p frameclock=%p frame_counter=%ld\n", \$gw, \$fc, (long) gdk_frame_clock_get_frame_counter (\$fc)
call (void) gtk_widget_queue_draw (\$w)
detach
quit
EOF
chmod 644 /tmp/kp4.gdb
sudo gdb -q -batch -p "$P" -x /tmp/kp4.gdb 2>&1 | grep -E '^gdkwindow'
sleep 3
sudo env $G grim -o DSI-2 -s 0.35 /tmp/gr-after.png
# frame counter again a bit later
cat > /tmp/kp5.gdb <<EOF
set pagination off
set confirm off
set \$gw = (void *) gtk_widget_get_window ((void *) $S)
printf "frame_counter later=%ld\n", (long) gdk_frame_clock_get_frame_counter ((void *) gdk_window_get_frame_clock (\$gw))
detach
quit
EOF
chmod 644 /tmp/kp5.gdb
sudo gdb -q -batch -p "$P" -x /tmp/kp5.gdb 2>&1 | grep -E '^frame_counter'
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
pgrep -x phrog >/dev/null && echo "phrog alive" || echo "phrog DEAD"
