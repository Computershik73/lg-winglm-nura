#!/bin/sh
grep -aE "qmi_vss_ims_service\.c|qmi_vss_ims_server\.c|vss_ims_" /tmp/qdb.txt | cut -d: -f3- | cut -c1-220 | sort -t: -k2 -n -u | head -80
