#!/bin/sh
mkdir -p /tmp/bu && cd /tmp/bu && [ -x usr/bin/objdump ] || tar xzf /tmp/bu.apk 2>/dev/null
export LD_LIBRARY_PATH=/tmp/bu/usr/lib
OD=/tmp/bu/usr/bin/objdump
$OD --version | head -1
L=/mnt/android/system_a/system/system_ext/lib64
cd /tmp
for f in libimsmmpf.lge.so libims.lge.so; do
  sudo cat $L/$f > /tmp/$f
  $OD -d --no-show-raw-insn -C /tmp/$f > /tmp/$f.dis 2>/dev/null
  echo "$f: $(wc -l < /tmp/$f.dis) lines"
done
