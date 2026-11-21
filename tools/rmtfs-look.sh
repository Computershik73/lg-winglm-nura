#!/bin/sh
grep -viE "^\s*$" /tmp/rmtfs.log | grep -vE "iovec|^\s+[0-9a-f]{4}:" | sort | uniq -c | sort -rn | head -30 | cut -c1-160
ls -la /var/lib/rmtfs/
cat /etc/conf.d/winglm-rmtfs 2>/dev/null; grep -E "command|args" /etc/init.d/winglm-rmtfs
