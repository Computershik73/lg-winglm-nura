import sys, os

src = sys.argv[1]  # phosh src/ dir
p = os.path.join(src, "monitor-manager.c")
s = open(p).read()
old = '''  g_signal_emit (self, signals[SIGNAL_MONITOR_ADDED], 0, monitor);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_N_MONITORS]);

  g_signal_handlers_disconnect_by_data (monitor, self);
'''
new = '''  /* Disconnect first: a handler of 'monitor-added' can run a Wayland
   * roundtrip (mapping a layer surface does) that delivers the output's
   * next 'done' and so 'configured' again while we're still in here,
   * announcing the same monitor twice */
  g_signal_handlers_disconnect_by_data (monitor, self);

  g_signal_emit (self, signals[SIGNAL_MONITOR_ADDED], 0, monitor);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_N_MONITORS]);
'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w").write(s)
print("patched monitor-manager.c")
