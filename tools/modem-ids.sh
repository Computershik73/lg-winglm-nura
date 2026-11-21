#!/bin/sh
Q="sudo timeout 20 qmicli -d qrtr://0"
$Q --dms-get-ids 2>&1 | sed 's/\(IMEI.*: .\)[0-9]\{8\}/\1XXXXXXXX/'
$Q --dms-get-revision 2>&1
$Q --dms-get-hardware-revision 2>&1
$Q --dms-get-band-capabilities 2>&1 | head -6
$Q --nas-get-rf-band-information 2>&1 | head -5
$Q --dms-get-factory-sku 2>&1
$Q --dms-get-software-version 2>&1
$Q --nas-get-tx-rx-info=lte 2>&1 | head -5
