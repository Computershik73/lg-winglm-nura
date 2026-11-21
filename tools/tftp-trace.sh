#!/bin/sh
command -v strace >/dev/null || sudo env http_proxy=http://127.0.0.1:8888 https_proxy=http://127.0.0.1:8888 apk add strace 2>&1 | tail -1
T=$(pgrep -x tqftpserv | head -1)
sudo setsid strace -f -tt -e trace=openat,open,stat,access -p $T -o /tmp/tqftp.strace > /dev/null 2>&1 < /dev/null &
sleep 1
for p in $(pgrep -f '^sleep 2147483647'); do sudo kill $p; done
sleep 5
sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 30
sudo pkill strace
grep -vE 'ENOENT.*/(usr|lib)/(lib|locale)|/etc/ld' /tmp/tqftp.strace | head -40 | cut -c1-200
echo "== requests (unique paths)"
grep -oE '"[^"]+"' /tmp/tqftp.strace | sort | uniq -c | sort -rn | head -30
