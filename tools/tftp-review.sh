#!/bin/sh
ls -la /tmp/tqftp.strace /tmp/rmtfs.log 2>&1
grep -oE '(openat|stat|access|mkdir)\([^"]*"[^"]+"[^=]*= -?[0-9]+( [A-Z]+)?' /tmp/tqftp.strace | grep -vE '/(usr|lib)/|ld-musl|/etc/ld|/proc/|/dev/' | sed -E 's/^[a-z]+\([^"]*//' | sort | uniq -c | sort -rn | head -60 | cut -c1-200
echo == rfs layout
ls -la /usr/share/qcom 2>/dev/null; cat /etc/conf.d/tqftpserv 2>/dev/null; ls -la /var/lib/tqftpserv 2>/dev/null | head
