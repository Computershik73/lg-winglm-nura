#!/bin/sh
cd /tmp && sudo apk add --no-network --allow-untrusted ./device-lg-winglm-1-r39.apk ./device-lg-winglm-phosh-1-r39.apk ./device-lg-winglm-dsp-1-r39.apk ./device-lg-winglm-volte-1-r39.apk 2>&1 | tail -1
rc-update show default | grep spk-gain
sudo rc-service winglm-spk-gain start 2>&1 | tail -1
sleep 1
ls -la /run/winglm-spk-gain
# restart the session helper (new version)
for p in $(pgrep -u user python3); do
	grep -q winglm-call-volume /proc/$p/cmdline 2>/dev/null && kill $p
done
sleep 3
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
pgrep -u user python3 | while read p; do grep -q winglm-call-volume /proc/$p/cmdline && echo "helper restarted: $p"; done
if ! pgrep -u user python3 | while read p; do grep -q winglm-call-volume /proc/$p/cmdline && exit 1; done; then :; else
	$E setsid /usr/libexec/winglm-call-volume >/dev/null 2>&1 < /dev/null &
	sleep 1; echo "helper started by hand"
fi
# service test while a tone plays
python3 /tmp/tone.py /tmp/tone6.wav 6 -30
$E paplay /tmp/tone6.wav &
sleep 1.5
echo "before: $(sudo python3 /tmp/tfa-read.py | tail -1 | cut -d, -f1)"
echo 50 > /run/winglm-spk-gain; sleep 1.5
echo "at 50 %: $(sudo python3 /tmp/tfa-read.py | tail -1 | cut -d, -f1)"
echo 100 > /run/winglm-spk-gain; sleep 1.5
echo "at 100 %: $(sudo python3 /tmp/tfa-read.py | tail -1 | cut -d, -f1)"
wait
cat /var/log/winglm-spk-gain.log
