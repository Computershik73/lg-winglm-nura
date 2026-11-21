#!/usr/bin/python3
"""Calls SIP: DTMF via SIP INFO (application/dtmf-relay), so the keypad works
in SIP calls (SIP calls had no send_dtmf_tone at all, can-dtmf was FALSE).
usage: apply_sip_dtmf.py TREE"""
import sys

p = '%s/plugins/provider/sip/calls-sip-call.c' % sys.argv[1]
s = open(p).read()


def edit(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit('expected one match of %r, found %d' % (old[:70], s.count(old)))
    s = s.replace(old, new)


edit('#include <sofia-sip/nua.h>\n',
     '#include <sofia-sip/nua.h>\n#include <sofia-sip/sip_tag.h>\n')

edit('static void\ncalls_sip_call_class_init (CallsSipCallClass *klass)\n',
     '/* RFC 2833/4733 events would need our own media pipeline; INFO with\n'
     ' * application/dtmf-relay (the common SIP INFO DTMF format) reaches\n'
     ' * gateways that do the media themselves */\n'
     'static void\n'
     'calls_sip_call_send_dtmf_tone (CallsCall *call,\n'
     '                               char       key)\n'
     '{\n'
     '  CallsSipCall *self = CALLS_SIP_CALL (call);\n'
     '  g_autofree char *body = NULL;\n'
     '\n'
     '  if (!self->nh) {\n'
     '    g_warning ("Can\'t send DTMF %c: no call handle", key);\n'
     '    return;\n'
     '  }\n'
     '\n'
     '  body = g_strdup_printf ("Signal=%c\\r\\nDuration=160\\r\\n", key);\n'
     '  g_debug ("Sending DTMF %c with SIP INFO", key);\n'
     '  nua_info (self->nh,\n'
     '            SIPTAG_CONTENT_TYPE_STR ("application/dtmf-relay"),\n'
     '            SIPTAG_PAYLOAD_STR (body),\n'
     '            TAG_END ());\n'
     '}\n\n'
     'static void\ncalls_sip_call_class_init (CallsSipCallClass *klass)\n')

edit('  call_class->hang_up = calls_sip_call_hang_up;\n',
     '  call_class->hang_up = calls_sip_call_hang_up;\n'
     '  call_class->send_dtmf_tone = calls_sip_call_send_dtmf_tone;\n')

open(p, 'w').write(s)
print('applied sip dtmf')
