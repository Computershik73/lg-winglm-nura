#!/bin/bash
# WSL: run-ttap.sh OUT LX LY NAME [WAIT]
SP=/mnt/c/Users/User/AppData/Local/Temp/claude/09dffbddec4c1633/dd1f1da9-6870-4ea2-9c9e-29465f940410/scratchpad
ssh -o BatchMode=yes user@172.16.42.1 "sh -s $1 $2 $3 $4 ${5:-2}" < $SP/ttap.sh
scp -q user@172.16.42.1:/tmp/$4-1.png user@172.16.42.1:/tmp/$4-2.png $SP/shots/
