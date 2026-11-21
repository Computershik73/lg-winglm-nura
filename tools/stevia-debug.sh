#!/bin/sh
# Start stevia inside the graphical session's cgroup (as gnome-session would), then test it
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
PP=$(pgrep -u user -x phosh | head -1)
CG=$(awk -F: '$1=="0" || $2=="name=elogind" || $2=="" {print $3}' /proc/$PP/cgroup | head -1)
echo "phosh cgroup: $(cat /proc/$PP/cgroup | tr '\n' ' ')"
for p in $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia'); do kill $p; done
cat > /tmp/stevia-wrap.sh <<EOF
#!/bin/sh
for f in /sys/fs/cgroup/elogind$CG/cgroup.procs /sys/fs/cgroup$CG/cgroup.procs /sys/fs/cgroup/unified$CG/cgroup.procs; do
	[ -w "\$f" ] && echo \$\$ > "\$f" 2>/dev/null && break
done
exec /usr/bin/phosh-osk-stevia --allow-replacement
EOF
chmod 755 /tmp/stevia-wrap.sh
# cgroup.procs needs root to write; run the wrapper via sudo -u user after moving with root
sudo sh -c "for f in /sys/fs/cgroup/elogind$CG/cgroup.procs /sys/fs/cgroup$CG/cgroup.procs; do [ -e \$f ] && echo \$f; done"
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
echo "osk output setting: $($E gsettings get mobi.phosh.osk output)"
$E setsid sh -c 'echo $$ > /tmp/stevia-wrap.pid; sleep 1; exec env G_MESSAGES_DEBUG=all /usr/bin/phosh-osk-stevia --allow-replacement' > /tmp/stevia.log 2>&1 < /dev/null &
sleep 0.3
W=$(cat /tmp/stevia-wrap.pid)
for f in /sys/fs/cgroup/elogind$CG/cgroup.procs /sys/fs/cgroup$CG/cgroup.procs; do
	[ -e "$f" ] && echo "$W" | sudo tee "$f" >/dev/null && echo "moved $W into $f" && break
done
sleep 6
pgrep -u user -f '^/usr/bin/phosh-osk-stevia' >/dev/null && echo "stevia running" || { echo "stevia DIED"; tail -5 /tmp/stevia.log; }
grep -iE 'critical|weak ref|unavailable|Segmentation' /tmp/stevia.log | head -5
