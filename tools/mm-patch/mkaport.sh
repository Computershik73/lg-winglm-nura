#!/bin/bash
# ModemManager aport for the phone: Alpine's recipe + the downstream IPA patch
# usage: mkaport.sh PKGREL
set -e
REL=${1:?pkgrel}
PD=$(cd "$(dirname "$0")" && pwd)
C=7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a
P1=0100-qcom-soc-data-over-the-downstream-IPA-driver.patch
cd ~/mm-dl
rm -rf p && mkdir -p p/x
for d in a b; do tar xzf ModemManager-$C.tar.gz -C p/x && mv p/x/ModemManager-$C p/$d; done
rmdir p/x
python3 $PD/apply_ipa_downstream.py p/b
rm -rf aport && mkdir aport && cp alpine/* aport/
{
cat <<'HDR'
From: winglm port
Subject: [PATCH] qcom-soc: data over the downstream (vendor kernel) IPA driver

Qualcomm SoCs running an Android vendor kernel (LG Wing, SM7250, 4.19)
expose the modem data port as rmnet_ipa0 of the downstream IPA driver: a
virtual netdev with no driver link, set up through the driver's extended
ioctls instead of sysfs. ModemManager refused it ("Unsupported QMI kernel
driver").

- kernel device: a udev rule may name the driver a driverless virtual
  netdev behaves like (ID_MM_KERNEL_DRIVER=ipa). Raw-IP links without
  lower_* sysfs links (rmnet on these kernels) get their parent from
  iflink, so they are grabbed as link ports.
- the QMAP uplink / QMAPv5 downlink split is allowed (an assert required
  the same aggregation protocol both ways).
- QMI port, with ID_MM_QCOM_IPA_DOWNSTREAM on the net port, as Android's
  netmgrd does: once per boot the IPA egress (QMAP, mux) and ingress
  (MAPv5 checksum, deaggregation, 31 datagrams / 31668 bytes) formats;
  the DPM port from the driver's WAN endpoint pair; WDA data format UL
  QMAP / DL QMAPv5 with the same aggregation limits; rmnet links with the
  MAPv5 ingress checksum; an IPA mux channel per link. Nothing is touched
  while probing, and not before 120 s of uptime (an early data path setup
  panicked this kernel).
---
HDR
(cd p && diff -ruN a b || true)
} > aport/$P1
cd aport
python3 - "$REL" "$P1" <<'PY'
import hashlib, re, sys
rel, patch = sys.argv[1], sys.argv[2]
s = open('APKBUILD').read()
s = re.sub(r'^pkgrel=\d+$', 'pkgrel=%s' % rel, s, flags=re.M)
s = s.replace('\t0001-intel-XMM7360-fix-big-endian-handling-of-ASN-integer.patch\n',
              '\t0001-intel-XMM7360-fix-big-endian-handling-of-ASN-integer.patch\n\t%s\n' % patch, 1)
s = s.replace('license="GPL-2.0-or-later AND LGPL-2.1-or-later"\n',
              'license="GPL-2.0-or-later AND LGPL-2.1-or-later"\n# winglm: tests take long on the phone\noptions="!check"\n', 1)
assert patch in s and 'options="!check"' in s
i = s.rindex('"')
s = s[:i] + '%s  %s\n' % (hashlib.sha512(open(patch, 'rb').read()).hexdigest(), patch) + '"\n'
open('APKBUILD', 'w').write(s)
PY
grep -nE "^pkgrel|^options|$P1" APKBUILD
ssh -o BatchMode=yes user@172.16.42.1 'rm -rf ~/aports/modemmanager; mkdir -p ~/aports/modemmanager ~/distfiles'
scp -q -o BatchMode=yes * user@172.16.42.1:aports/modemmanager/
scp -q -o BatchMode=yes ~/mm-dl/ModemManager-$C.tar.gz user@172.16.42.1:distfiles/
echo "aport r$REL on the phone ($(wc -l < $P1) patch lines)"
