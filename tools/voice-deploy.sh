#!/bin/sh
# test deploy of winglm-voice instead of q6voiced
sudo install -m755 /tmp/winglm-voice /usr/bin/winglm-voice
sudo install -m755 /tmp/winglm-voice.initd /etc/init.d/winglm-voice
sudo rc-service q6voiced stop 2>&1 | tail -1
sudo rc-service winglm-voice start 2>&1 | tail -1
sleep 2
rc-service winglm-voice status
sudo cat /var/log/winglm-voice.log
pgrep -a -f '^/usr/bin/python3 /usr/bin/winglm-voice' | head -2
ps -o user,group,args | grep '[w]inglm-voice' | head -2
cat /run/winglm-volte/status | head -2
