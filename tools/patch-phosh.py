import sys, os
d = sys.argv[1]
p = os.path.join(d, "layersurface.c")
s = open(p).read()
old = '''    g_param_spec_pointer ("wl-output", "", "",
                          G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);'''
new = '''    g_param_spec_pointer ("wl-output", "", "",
                          G_PARAM_READWRITE | G_PARAM_CONSTRUCT | G_PARAM_STATIC_STRINGS);'''
assert s.count(old) == 1, "layersurface"
open(p, "w").write(s.replace(old, new))

p = os.path.join(d, "shell.c")
s = open(p).read()
old = '''    PhoshMonitor *tmp = phosh_monitor_manager_get_monitor (priv->monitor_manager, i);
    if (phosh_monitor_is_builtin (tmp) && tmp != old) {
      monitor = tmp;
      break;
    }'''
new = '''    PhoshMonitor *tmp = phosh_monitor_manager_get_monitor (priv->monitor_manager, i);

    if (!phosh_monitor_is_builtin (tmp) || tmp == old)
      continue;

    /* Devices with a second, smaller built-in panel: prefer the largest one */
    if (monitor == NULL ||
        (gint64) tmp->width_mm * tmp->height_mm >
        (gint64) monitor->width_mm * monitor->height_mm)
      monitor = tmp;'''
assert s.count(old) == 1, "shell"
open(p, "w").write(s.replace(old, new))
print("patched")
