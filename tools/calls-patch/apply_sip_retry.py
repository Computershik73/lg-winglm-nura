#!/usr/bin/python3
"""Calls SIP: keep retrying the registration of an auto-connect account after
a temporary failure (503, 408, 5xx) instead of staying offline until Calls is
restarted.  usage: apply_sip_retry.py TREE"""
import sys

tree = sys.argv[1]
p = '%s/plugins/provider/sip/calls-sip-origin.c' % tree
s = open(p).read()


def edit(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit('expected one match of %r, found %d' % (old[:70], s.count(old)))
    s = s.replace(old, new)


edit('  GList                *calls;\n  GHashTable           *call_handles;\n};\n',
     '  GList                *calls;\n  GHashTable           *call_handles;\n\n'
     '  guint                 register_retry_id;\n};\n')

edit('static void\nsip_r_register (int              status,\n',
     '#define REGISTER_RETRY_S 30\n\n'
     'static void go_online (CallsAccount *account, gboolean online);\n\n'
     'static gboolean\n'
     'register_retry_cb (gpointer user_data)\n'
     '{\n'
     '  CallsSipOrigin *self = CALLS_SIP_ORIGIN (user_data);\n'
     '\n'
     '  self->register_retry_id = 0;\n'
     '  if (self->auto_connect && self->state != CALLS_ACCOUNT_STATE_ONLINE) {\n'
     '    g_debug ("Retrying the registration");\n'
     '    go_online (CALLS_ACCOUNT (self), TRUE);\n'
     '  }\n'
     '\n'
     '  return G_SOURCE_REMOVE;\n'
     '}\n\n'
     '/* A temporary failure (the registrar is not ready yet, e.g. a local\n'
     ' * gateway waiting for its upstream) must not leave the account offline\n'
     ' * until Calls is restarted */\n'
     'static void\n'
     'schedule_register_retry (CallsSipOrigin *self)\n'
     '{\n'
     '  if (!self->auto_connect || self->register_retry_id)\n'
     '    return;\n'
     '\n'
     '  self->register_retry_id = g_timeout_add_seconds (REGISTER_RETRY_S, register_retry_cb, self);\n'
     '}\n\n'
     'static void\nsip_r_register (int              status,\n')

edit('  } else if (status == 503) {\n'
     '    change_state (origin,\n'
     '                  CALLS_ACCOUNT_STATE_OFFLINE,\n'
     '                  CALLS_ACCOUNT_STATE_REASON_CONNECTION_DNS_ERROR);\n'
     '  } else if (status == 904) {\n',
     '  } else if (status == 503) {\n'
     '    change_state (origin,\n'
     '                  CALLS_ACCOUNT_STATE_OFFLINE,\n'
     '                  CALLS_ACCOUNT_STATE_REASON_CONNECTION_DNS_ERROR);\n'
     '    schedule_register_retry (origin);\n'
     '  } else if (status == 904) {\n')

edit('    g_warning ("REGISTER: %d %s", status, phrase);\n'
     '    change_state (origin,\n'
     '                  CALLS_ACCOUNT_STATE_ERROR,\n'
     '                  CALLS_ACCOUNT_STATE_REASON_INTERNAL_ERROR);\n'
     '  }\n',
     '    g_warning ("REGISTER: %d %s", status, phrase);\n'
     '    change_state (origin,\n'
     '                  CALLS_ACCOUNT_STATE_ERROR,\n'
     '                  CALLS_ACCOUNT_STATE_REASON_INTERNAL_ERROR);\n'
     '    if (status == 408 || status >= 500)\n'
     '      schedule_register_retry (origin);\n'
     '  }\n')

edit('  } else {\n'
     '    if (self->state == CALLS_ACCOUNT_STATE_OFFLINE)\n'
     '      return;\n\n'
     '    nua_unregister (self->oper->register_handle,\n',
     '  } else {\n'
     '    g_clear_handle_id (&self->register_retry_id, g_source_remove);\n\n'
     '    if (self->state == CALLS_ACCOUNT_STATE_OFFLINE)\n'
     '      return;\n\n'
     '    nua_unregister (self->oper->register_handle,\n')

edit('  CallsSipOrigin *self = CALLS_SIP_ORIGIN (object);\n'
     '  gboolean su_step_timeout = FALSE;\n'
     '  guint i = 0;\n\n',
     '  CallsSipOrigin *self = CALLS_SIP_ORIGIN (object);\n'
     '  gboolean su_step_timeout = FALSE;\n'
     '  guint i = 0;\n\n'
     '  g_clear_handle_id (&self->register_retry_id, g_source_remove);\n\n')

open(p, 'w').write(s)
print('applied sip retry')
