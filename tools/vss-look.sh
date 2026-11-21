#!/bin/sh
echo "== simlock.c"
grep -E ":simlock\.c:" /tmp/qdb.txt | awk -F: '$4>=780 && $4<=900' | cut -d: -f4- | cut -c1-170
echo "== vss server/service msgs"
grep -E ":qmi_vss_resim_(service|server)\.c:" /tmp/qdb.txt | cut -d: -f4- | cut -c1-170 | head -80
