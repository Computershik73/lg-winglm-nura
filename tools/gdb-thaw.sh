#!/bin/sh
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
STATE=/sys/class/smartcover/swivel/state
G="XDG_RUNTIME_DIR=/run/user/108 WAYLAND_DISPLAY=wayland-0"
P=$(pgrep -x phrog | head -1)
real=$(cat $STATE)
echo 2 | sudo tee $INJ >/dev/null
sleep 6
S=$(grep -oE 'shield 0x[0-9a-f]+ on DSI-2' /tmp/phrog-session.log | tail -1 | awk '{print $2}')
echo "shield=$S"
cat > /tmp/kp6.gdb <<EOF
set pagination off
set confirm off
set \$w = (void *) $S
set \$gw = (void *) gtk_widget_get_window (\$w)
set \$fc = (void *) gdk_window_get_frame_clock (\$gw)
set \$ww = (int *) malloc (8)
call (void) gtk_window_get_size (\$w, \$ww, \$ww + 1)
printf "gdk %dx%d gtk_window_get_size %dx%d frames=%ld\n", (int) gdk_window_get_width (\$gw), (int) gdk_window_get_height (\$gw), \$ww[0], \$ww[1], (long) gdk_frame_clock_get_frame_counter (\$fc)
call (void) gdk_window_thaw_toplevel_updates_libgtk_only (\$gw)
call (void) gtk_widget_queue_draw (\$w)
detach
quit
EOF
chmod 644 /tmp/kp6.gdb
sudo gdb -q -batch -p "$P" -x /tmp/kp6.gdb 2>&1 | grep -E '^gdk '
sleep 3
sudo env $G grim -o DSI-2 -s 0.35 /tmp/gr-thaw.png
cat > /tmp/kp7.gdb <<EOF
set pagination off
set confirm off
set \$gw = (void *) gtk_widget_get_window ((void *) $S)
printf "frames later=%ld\n", (long) gdk_frame_clock_get_frame_counter ((void *) gdk_window_get_frame_clock (\$gw))
detach
quit
EOF
chmod 644 /tmp/kp7.gdb
sudo gdb -q -batch -p "$P" -x /tmp/kp7.gdb 2>&1 | grep -E '^frames'
tail -n 8 /tmp/phrog-session.log | grep -iE 'critical|warn' | cut -c1-200
echo "$real" | sudo tee $INJ >/dev/null
sleep 2
pgrep -x phrog >/dev/null && echo "phrog alive" || echo "phrog DEAD"
