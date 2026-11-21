#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pkill -u user -x callaudiod; sleep 1
$E G_MESSAGES_DEBUG=all setsid /usr/bin/callaudiod > /tmp/cad.log 2>&1 < /dev/null &
[ -x /usr/bin/callaudiod ] || { ls /usr/lib*/callaudiod* /usr/bin/callaudiod 2>/dev/null; }
sleep 2
$E callaudiocli -m 1 2>&1 | tail -1; sleep 2
$E callaudiocli -s 1 2>&1 | tail -1; sleep 2
$E callaudiocli -m 0 2>&1 | tail -1; sleep 1
grep -vE "^\s*$" /tmp/cad.log | grep -iE "speaker|port|profile|card|sink|fail|error|warn" | head -40 | cut -c1-200
