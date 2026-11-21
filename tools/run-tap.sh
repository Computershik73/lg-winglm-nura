#!/bin/bash
# WSL helper: run tap.sh on the phone and fetch the screenshots
X=$1; Y=$2; N=${3:-tap}; W=${4:-2}
SP=/mnt/c/Users/User/AppData/Local/Temp/claude/09dffbddec4c1633/dd1f1da9-6870-4ea2-9c9e-29465f940410/scratchpad
ssh -o BatchMode=yes user@172.16.42.1 "sh -s $X $Y $N $W" < $SP/tap.sh
scp -q user@172.16.42.1:/tmp/$N-1.png user@172.16.42.1:/tmp/$N-2.png $SP/shots/
