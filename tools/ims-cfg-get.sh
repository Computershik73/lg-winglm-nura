#!/bin/sh
mkdir -p /tmp/imscfg
cd /mnt/android
sudo python3 - <<'EOF'
import zipfile
z = zipfile.ZipFile('system_a/system/system_ext/priv-app/Ims6/Ims6.apk')
for n in ('assets/Configuration/MGF/RU/media.MGF.RU.xml', 'assets/Configuration/MGF/RU/configuration.MGF.RU.xml',
          'assets/Configuration/media.xml', 'assets/Configuration/configuration.xml'):
    open('/tmp/imscfg/' + n.split('/')[-1], 'wb').write(z.read(n))
EOF
sudo chown -R user /tmp/imscfg
ls -la /tmp/imscfg
