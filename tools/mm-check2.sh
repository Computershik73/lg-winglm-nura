#!/bin/sh
M=$(mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | head -1 | cut -d/ -f2)
mmcli -m $M 2>&1 | grep -iE "fail|reason|state" 
logread 2>/dev/null | grep -i modemmanager | tail -25 | cut -c1-220
cat /etc/init.d/modemmanager | grep -E "command|need|use|after" | head
ls /usr/share/dbus-1/system-services/ | grep -i modem
