mkdir -p /sys/fs/pstore
mount -t pstore pstore /sys/fs/pstore 2>&1
ls -la /sys/fs/pstore
f=$(ls /sys/fs/pstore | grep -E 'console|dmesg' | head -1)
echo "--- crash markers in $f"
grep -nE 'Kernel panic|Unable to handle|Internal error|BUG:|watchdog|Call trace|pc :|lr :|Oops|SError|subsys|SSR|crash|restart|reboot|panic' "/sys/fs/pstore/$f" | tail -40 | cut -c1-200
echo "--- last 40 lines"
tail -n 40 "/sys/fs/pstore/$f" | cut -c1-200
