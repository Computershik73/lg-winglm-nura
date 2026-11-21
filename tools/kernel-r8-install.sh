#!/bin/sh
set -e
before=$(sha256sum /boot/boot.img | cut -c1-16)
sudo apk add --no-network --allow-untrusted /tmp/linux-lg-winglm-4.19.325-r8.apk 2>&1 | tail -3
apk info -v 2>/dev/null | grep '^linux-lg-winglm'
ls -la /boot/boot.img /boot/vmlinuz
echo "boot.img before $before after $(sha256sum /boot/boot.img | cut -c1-16)"
# boot.img v? header: cmdline at offset 64 (v0-2: 512 bytes)
python3 - <<'PY'
import struct, hashlib
d = open('/boot/boot.img', 'rb').read(4096)
assert d[:8] == b'ANDROID!', d[:8]
ksize = struct.unpack_from('<I', d, 8)[0]
ver = struct.unpack_from('<I', d, 40)[0]
cmd = d[64:64 + 512].split(b'\0')[0]
print('header v%d kernel %d bytes, cmdline %d chars' % (ver, ksize, len(cmd)))
print('cmdline tail:', cmd[-90:].decode())
PY
zcat -f /boot/vmlinuz 2>/dev/null | strings | grep -m1 "Linux version" | cut -c1-110 || true
