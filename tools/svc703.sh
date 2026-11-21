#!/bin/sh
cd /usr/lib/winglm-volte
sudo python3 - <<'EOF'
import qmiqrtr
for s in (703, 800):
    try:
        print(s, qmiqrtr.lookup(s, 2.0))
    except Exception as e:
        print(s, e)
EOF
