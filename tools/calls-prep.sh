#!/bin/sh
echo "== net"; ip route | grep default; ping -c1 -W3 dl-cdn.alpinelinux.org 2>&1 | tail -1
echo "== repos"; cat /etc/apk/repositories
echo "== local packages"; ls ~/packages/aports/aarch64/ 2>/dev/null | grep -E 'callaudiod|phosh-[0-9]|glib-[0-9]|phoc-[0-9]' | head
echo "== installed"; apk info -v 2>/dev/null | grep -E '^(callaudiod|glib|calls|libcall-ui|gmobile)'
echo "== abuild"; ls ~/.abuild/*.rsa.pub 2>/dev/null; id | tr ',' '\n' | grep -c abuild
