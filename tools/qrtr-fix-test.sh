#!/bin/sh
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE 'qrtr(-libs|-dev|-doc)?'); do pkgs="$pkgs $p=1.2-r10"; done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|ERROR' | tail -3
# modem stays up: register the daemons now (this is what failed before)
sudo pkill -x pd-mapper; sudo pkill -x tqftpserv; sudo pkill -x rmtfs; sleep 1
sudo setsid pd-mapper > /tmp/pd-mapper.log 2>&1 < /dev/null &
sudo setsid tqftpserv > /tmp/tqftp.log 2>&1 < /dev/null &
sudo setsid rmtfs -o /var/lib/rmtfs -v > /tmp/rmtfs.log 2>&1 < /dev/null &
sleep 2
grep -E 'add server \[(64|4096|14):' /tmp/qrtr-ns.log | tail -4
# restart the modem so it sees TFTP + locator at boot
for p in $(pgrep -f '^sleep 2147483647'); do sudo kill $p; done
sleep 5
T=$(pgrep -x tqftpserv | head -1)
sudo setsid strace -f -e trace=openat -p $T -o /tmp/tqftp.strace > /dev/null 2>&1 < /dev/null &
sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 40
sudo pkill strace
echo "== tftp opens"; grep -oE '"[^"]+"' /tmp/tqftp.strace | grep -vE '/(usr/)?lib/lib|ld-musl|/etc/' | sort | uniq -c | head -20
echo "== registrations after modem restart"; grep -E 'add server \[(64|4096|14|69):' /tmp/qrtr-ns.log | tail -6
sudo cat /sys/kernel/debug/icnss/stats | sed -n 1,9p
dmesg | tail -300 | grep -iE 'icnss|wlan|cld|hdd|wlfw|bdf|qca' | grep -v CAM_ | tail -20 | cut -c1-170
ls /sys/class/net | tr '\n' ' '; echo
