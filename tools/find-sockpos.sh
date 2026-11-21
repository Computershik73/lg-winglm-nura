#!/bin/sh
cd /mnt/android
sudo grep -rlas "socket_pos" system_a product_a 2>/dev/null | grep -v "\.so$" | head -20
echo ---
for f in $(sudo grep -rlas "socket_pos" system_a product_a 2>/dev/null | grep -v "\.so$" | head -5); do
  echo "== $f"; sudo ls -la "$f"
done
