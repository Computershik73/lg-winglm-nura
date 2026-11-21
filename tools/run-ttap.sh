#!/bin/bash
# WSL: run-ttap.sh OUT LX LY NAME [WAIT]
SP=$HOME/lg-winglm-nura/tools
ssh -o BatchMode=yes user@172.16.42.1 "sh -s $1 $2 $3 $4 ${5:-2}" < $SP/ttap.sh
scp -q user@172.16.42.1:/tmp/$4-1.png user@172.16.42.1:/tmp/$4-2.png $SP/shots/
