#!/bin/sh
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
$E gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.gnome.Mutter.DisplayConfig.GetCurrentState > /tmp/dispcfg.txt 2>&1
python3 - <<'EOF'
import re
s = open('/tmp/dispcfg.txt').read()
print(len(s), 'bytes')
# monitors: ((connector, vendor, product, serial), [modes], {props})
for m in re.finditer(r"\(\('(DSI-\d|DP-\d|Virtual-\d)', '([^']*)', '([^']*)', '([^']*)'\), \[(.*?)\], \{(.*?)\}\)", s, re.S):
    modes = m.group(5)
    cur = 'is-current' in modes
    print('monitor', m.group(1), 'modes', modes.count("('"), 'current-mode', cur, 'props', m.group(6)[:200])
i = s.find('], [(')
print('logical monitors part:', s[s.rfind('[(', 0, len(s)) - 600:][:900])
EOF
