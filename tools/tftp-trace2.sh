#!/bin/sh
# What does the modem ask tqftpserv for during boot, and what fails?
T=$(pgrep -x tqftpserv | head -1)
sudo setsid strace -f -tt -e trace=openat,open,stat,access,mkdir -p $T -o /tmp/tqftp.strace > /dev/null 2>&1 < /dev/null &
sleep 1
sudo rc-service winglm-modem restart >/dev/null 2>&1
sleep 40
sudo pkill -x strace; sleep 0.5
echo "== failed"
grep -E "= -1" /tmp/tqftp.strace | grep -vE '/(usr|lib)/(lib|locale)|ld-musl|/etc/ld' | grep -oE '"[^"]+".*= -1 [A-Z]+' | sort | uniq -c | sort -rn | head -30 | cut -c1-170
echo "== ok"
grep -vE "= -1" /tmp/tqftp.strace | grep -oE 'openat\([^"]*"[^"]+"' | grep -oE '"[^"]+"' | sort | uniq -c | sort -rn | head -25
echo "mode: $(sudo timeout 30 qmicli -d qrtr://0 --dms-get-operating-mode 2>&1 | grep Mode)"
