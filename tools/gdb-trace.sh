#!/bin/sh
# Attach to the running greeter and log keypad placement calls.
P=$(pgrep -x phrog | head -1)
[ -n "$P" ] || { echo "no phrog"; exit 1; }
cat > /tmp/kp.gdb <<'EOF'
set pagination off
set confirm off
handle SIGPIPE nostop noprint pass
handle SIG32 nostop noprint pass
handle SIG33 nostop noprint pass
break phosh_lockscreen_set_keypad_container
commands
silent
printf "set_keypad_container ls=%p container=%p w=%d h=%d\n", $x0, $x1, (int)phosh_layer_surface_get_configured_width($x0), (int)phosh_layer_surface_get_configured_height($x0)
continue
end
break phosh_lockshield_new
commands
silent
printf "lockshield_new monitor=%p\n", $x1
continue
end
break phosh_lockshield_get_keypad_box
commands
silent
printf "get_keypad_box shield=%p\n", $x0
continue
end
continue
detach
quit
EOF
chmod 644 /tmp/kp.gdb
sudo rm -f /tmp/kp-trace.log
# runs until interrupted with SIGINT, then detaches
sudo setsid gdb -q -batch -p "$P" -x /tmp/kp.gdb > /tmp/kp-trace.log 2>&1 < /dev/null &
sleep 8
echo "attached to phrog $P"
grep -E "Breakpoint|warning: Could not|No symbol" /tmp/kp-trace.log | head -5
