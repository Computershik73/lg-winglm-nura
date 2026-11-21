#!/usr/bin/python3
"""Apply the second-screen dial pad changes to a pristine calls-51.1 tree.
usage: apply.py TREE PATCHDIR"""
import shutil
import sys

tree, pdir = sys.argv[1], sys.argv[2]


def edit(path, old, new, count=1):
    p = '%s/%s' % (tree, path)
    s = open(p).read()
    if s.count(old) != count:
        raise SystemExit('%s: expected %d match(es) of %r, found %d' % (path, count, old[:60], s.count(old)))
    open(p, 'w').write(s.replace(old, new))


for f in ('calls-dialpad-window.c', 'calls-dialpad-window.h'):
    shutil.copy('%s/%s' % (pdir, f), '%s/src/%s' % (tree, f))

edit('src/meson.build', "  'calls-main-window.c',\n",
     "  'calls-dialpad-window.c',\n  'calls-main-window.c',\n")

edit('src/calls-main-window.h',
     'void             calls_main_window_show_accounts_overview   (CallsMainWindow *self);\n',
     'void             calls_main_window_show_accounts_overview   (CallsMainWindow *self);\n'
     'void             calls_main_window_set_dialpad_page_visible (CallsMainWindow *self,\n'
     '                                                            gboolean         visible);\n')

edit('src/calls-main-window.c',
     'void\ncalls_main_window_show_accounts_overview (CallsMainWindow *self)\n',
     '/* the dial pad has a window of its own on a second screen */\n'
     'void\n'
     'calls_main_window_set_dialpad_page_visible (CallsMainWindow *self,\n'
     '                                            gboolean         visible)\n'
     '{\n'
     '  AdwViewStackPage *page;\n'
     '\n'
     '  g_return_if_fail (CALLS_IS_MAIN_WINDOW (self));\n'
     '\n'
     '  page = adw_view_stack_get_page (self->main_stack, GTK_WIDGET (self->new_call));\n'
     '  if (!visible && g_strcmp0 (adw_view_stack_get_visible_child_name (self->main_stack), "dial-pad") == 0)\n'
     '    adw_view_stack_set_visible_child_name (self->main_stack, "recent");\n'
     '  adw_view_stack_page_set_visible (page, visible);\n'
     '}\n'
     '\n'
     'void\ncalls_main_window_show_accounts_overview (CallsMainWindow *self)\n')

app = 'src/calls-application.c'
edit(app, '#include "calls-new-call-box.h"\n',
     '#include "calls-dialpad-window.h"\n#include "calls-new-call-box.h"\n')
edit(app, '  CallsCallWindow    *call_window;\n',
     '  CallsCallWindow    *call_window;\n  CallsDialpadWindow *dialpad_window;\n')
edit(app,
     '  if (self->call_window)\n'
     '    gtk_application_remove_window (GTK_APPLICATION (self), GTK_WINDOW (self->call_window));\n',
     '  if (self->call_window)\n'
     '    gtk_application_remove_window (GTK_APPLICATION (self), GTK_WINDOW (self->call_window));\n'
     '\n'
     '  if (self->dialpad_window)\n'
     '    gtk_application_remove_window (GTK_APPLICATION (self), GTK_WINDOW (self->dialpad_window));\n')
edit(app,
     '  if (self->call_window)\n'
     '    gtk_window_destroy (GTK_WINDOW (self->call_window));\n',
     '  if (self->call_window)\n'
     '    gtk_window_destroy (GTK_WINDOW (self->call_window));\n'
     '  if (self->dialpad_window)\n'
     '    gtk_window_destroy (GTK_WINDOW (self->dialpad_window));\n')
edit(app,
     '  g_signal_connect (G_OBJECT (self->main_window),\n'
     '                    "hide",\n',
     '  self->dialpad_window = calls_dialpad_window_new (gtk_app,\n'
     '                                                  GTK_WINDOW (self->main_window),\n'
     '                                                  GTK_WINDOW (self->call_window));\n'
     '\n'
     '  g_signal_connect (G_OBJECT (self->main_window),\n'
     '                    "hide",\n')

edit('data/org.gnome.Calls.gschema.xml', '\n  </schema>\n',
     '\n'
     '    <key name="dialpad-monitor" type="s">\n'
     "      <default>''</default>\n"
     '      <summary>Screen for a separate dial pad</summary>\n'
     '      <description>Connector name (for example DSI-2) of a second screen. While Calls is\n'
     '      in front and this screen is connected, the dial pad (and, during a call, the\n'
     '      DTMF keypad) is shown fullscreen on it and not in the main window. Empty: off.</description>\n'
     '    </key>\n'
     '\n  </schema>\n')
print('applied')
