#!/bin/sh
# Restart the modem with a logging tqftpserv to see what it fetches
sudo rc-service tqftpserv stop >/dev/null 2>&1; sudo pkill -x tqftpserv; sleep 1
sudo setsid tqftpserv > /tmp/tqftp.log 2>&1 < /dev/null &
sleep 1
for p in $(pgrep -f 'exec sleep 2147483647'); do sudo kill $p; done
for p in $(pgrep -f '^sleep 2147483647'); do sudo kill $p; done
sleep 5
for s in /sys/bus/msm_subsys/devices/*; do [ "$(cat $s/name)" = modem ] && echo "modem after close: $(cat $s/state)"; done
M=$(dmesg | wc -l)
sudo setsid sh -c 'exec 3</dev/subsys_modem; exec sleep 2147483647' > /dev/null 2>&1 < /dev/null &
sleep 25
for s in /sys/bus/msm_subsys/devices/*; do [ "$(cat $s/name)" = modem ] && echo "modem: $(cat $s/state)"; done
echo "== tqftpserv"; head -30 /tmp/tqftp.log | cut -c1-160
echo "== dmesg"; dmesg | tail -n +$M | grep -iE 'icnss|cnss|wlan|modem|pil|wlfw|esoc|ssr|subsys' | head -20 | cut -c1-170
ls /sys/class/net | tr '\n' ' '; echo
