#!/bin/sh
# test deploy: 3600 s registration, re-REGISTER every 300 s, waiting for the
# network's re-authentication (401 to a re-REGISTER)
sudo cp /tmp/volte/imsreg2.py /tmp/volte/volted.py /usr/lib/winglm-volte/
sudo mkdir -p /etc/winglm-volte
echo 3600 | sudo tee /etc/winglm-volte/expires >/dev/null
echo 300 | sudo tee /etc/winglm-volte/refresh >/dev/null
sudo rm -f /etc/winglm-volte/test-reregister
echo "trace line $(sudo wc -l < /var/log/winglm-volte.trace)"
sudo rc-service winglm-volte restart 2>&1 | tail -1
