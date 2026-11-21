#!/bin/sh
echo "== pcscf/register/sip strings: $(grep -ciE 'pcscf|p-cscf' /tmp/qdb.txt) pcscf, $(grep -cE 'REGISTER|INVITE' /tmp/qdb.txt) REGISTER/INVITE"
grep -iE "pcscf|p-cscf" /tmp/qdb.txt | awk -F: '{print $5": "$6}' | sort -u | head -15 | cut -c1-200
echo "== qmi_vss_ims_server/service"
grep -E ":qmi_vss_ims_(server|service)\.c:" /tmp/qdb.txt | awk -F: '{print $5": "$6}' | cut -c1-200
echo "== policyman_ims_config / volte"
grep -E ":(policyman_ims_config|policyman_volte)\.c:" /tmp/qdb.txt | awk -F: '{print $5": "$6}' | cut -c1-200
echo "== qmi_nas_ims_extn (first 25)"
grep -E ":qmi_nas_ims_extn\.c:" /tmp/qdb.txt | awk -F: '{print $6}' | head -25 | cut -c1-200
echo "== qmi_voice_ims_extn"
grep -E ":qmi_voice_ims_extn\.c:" /tmp/qdb.txt | awk -F: '{print $6}' | cut -c1-200
echo "== lrtp_session (first 15)"
grep -E ":lrtp_session\.cpp:" /tmp/qdb.txt | awk -F: '{print $6}' | head -15 | cut -c1-200
