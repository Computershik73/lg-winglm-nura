#!/bin/sh
M=$(mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | head -1 | cut -d/ -f2)
mmcli -m $M 2>&1 | grep -E "state|power|access tech|signal quality|operator name|registration|primary sim|sim slot|current modes|own" | head -20
pgrep -a gnome-calls || pgrep -af "/usr/bin/gnome-calls|calls --daemon" ; pgrep -a callaudiod; pgrep -a q6voiced
