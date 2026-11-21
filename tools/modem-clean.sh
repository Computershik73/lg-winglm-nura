#!/bin/sh
# Clean order: modem down, name service and daemons up, then the modem once
for p in $(pgrep -f '^sleep 2147483647'); do sudo kill $p; done
sleep 4
sudo pkill -x rmtfs; sudo rc-service tqftpserv stop >/dev/null 2>&1; sudo rc-service pd-mapper stop >/dev/null 2>&1
sudo rc-service qrtr-ns restart >/dev/null 2>&1; sleep 1
sudo rc-service pd-mapper start >/dev/null 2>&1
sudo rc-service tqftpserv start >/dev/null 2>&1
sudo setsid rmtfs -o /var/lib/rmtfs -v > /tmp/rmtfs.log 2>&1 < /dev/null &
sleep 2
echo "== local services before the modem"
qrtr-lookup | awk 'NR==1 || ($4 == 1 && $1 != 4097)'
T=$(pgrep -x tqftpserv | head -1)
sudo setsid strace -f -e trace=openat -p $T -o /tmp/tqftp.strace > /dev/null 2>&1 < /dev/null &
sleep 1
sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 35
sudo pkill strace
echo "== tftp opens"; grep -oE 'openat\([^"]*"[^"]+"[^)]*\) = -?[0-9]+( [A-Z]+)?' /tmp/tqftp.strace | grep -vE '/(usr/)?lib/lib|ld-musl' | sed 's/openat(AT_FDCWD, //' | sort | uniq -c | head -20
echo "== wlfw / tftp"; qrtr-lookup | awk 'NR==1 || $1 == 69 || $1 == 4096 || $1 == 64'
sudo cat /sys/kernel/debug/icnss/stats | sed -n 1,6p
dmesg | tail -200 | grep -iE 'icnss|wlan|cld|hdd|wlfw|bdf' | grep -v CAM_ | tail -15 | cut -c1-170
ls /sys/class/net | tr '\n' ' '; echo
