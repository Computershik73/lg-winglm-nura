#!/bin/sh
# deploy imsreg2 fix; VoLTE off (guard file) to test the CS fallback
sudo cp /tmp/volte/imsreg2.py /usr/lib/winglm-volte/
echo test | sudo tee /var/lib/winglm-volte/ipa-guard >/dev/null
sudo rc-service winglm-volte restart 2>&1 | tail -1
sleep 75
sudo grep -aE "GNOME Calls REGISTER|VoLTE off|disabled|IMS" /var/log/winglm-volte.trace | tail -6 | cut -c1-120
cat /run/winglm-volte/status
