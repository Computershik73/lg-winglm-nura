import glob, os, sys
base = glob.glob('/run/msm-firmware-loader/mnt/modem*/image/modem_pr/mcfg/configs/mcfg_sw/generic')[0]
keys = [b'IMS_enable', b'voice_domain_pref', b'allow_csfb_upon_ims_reg', b'ims_reg_status_wait_timer',
        b'sms_domain_pref', b'max_ims_reg_attempt_timer', b'lte_nas_ignore_mt_csfb_during_volte_call']
for prof in sys.argv[1:]:
    d = open(os.path.join(base, prof, 'mcfg_sw.mbn'), 'rb').read()
    print('==', prof, len(d))
    for k in keys:
        i = d.find(k)
        while i >= 0:
            s = d.rfind(b'/nv/', 0, i)
            e = d.find(b'\0', i)
            path = d[s:e].decode(errors='replace')
            pre = d[s - 16:s].hex(' ')
            post = d[e + 1:e + 13].hex(' ')
            print('  %-60s pre[%s] post[%s]' % (path, pre, post))
            i = d.find(k, i + 1)
