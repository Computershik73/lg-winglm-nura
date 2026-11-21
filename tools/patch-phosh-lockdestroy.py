import os
import sys

top = sys.argv[1]   # phosh source dir with 0001-0007 applied


def edit(name, pairs):
    p = os.path.join(top, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r" % (name, old[:70])
        s = s.replace(old, new)
    open(p, "w").write(s)


edit("src/lockscreen-manager.c", [
(
'''  g_return_if_fail (PHOSH_IS_LOCKSCREEN (lockscreen));
  g_return_if_fail (lockscreen == PHOSH_LOCKSCREEN (self->lockscreen));

  g_signal_handlers_disconnect_by_data (monitor_manager, self);
  g_signal_handlers_disconnect_by_data (primary_monitor, self);
  g_signal_handlers_disconnect_by_data (shell, self);
  phosh_lockscreen_set_keypad_container (self->lockscreen, NULL);
  g_clear_pointer (&self->lockscreen, phosh_cp_widget_destroy);
''',
'''  /* NULL: the compositor closed the lockscreen (see on_lockscreen_destroyed) */
  g_return_if_fail (lockscreen == NULL || PHOSH_IS_LOCKSCREEN (lockscreen));
  g_return_if_fail (lockscreen == self->lockscreen);

  g_signal_handlers_disconnect_by_data (monitor_manager, self);
  if (primary_monitor)
    g_signal_handlers_disconnect_by_data (primary_monitor, self);
  g_signal_handlers_disconnect_by_data (shell, self);
  if (self->lockscreen)
    phosh_lockscreen_set_keypad_container (self->lockscreen, NULL);
  g_clear_pointer (&self->lockscreen, phosh_cp_widget_destroy);
'''),
(
'''static void
lock_primary_monitor (PhoshLockscreenManager *self)
{''',
'''/* The compositor can close a lockscreen right after it was created (its
 * output went away meanwhile, e.g. all screens blanked during startup):
 * don't keep a pointer to the destroyed widget */
static void
on_lockscreen_destroyed (PhoshLockscreenManager *self, GtkWidget *lockscreen)
{
  if (GTK_WIDGET (self->lockscreen) != lockscreen)
    return;

  g_debug ("Lockscreen %p closed by the compositor", lockscreen);
  self->lockscreen = NULL;
}


static void
lock_primary_monitor (PhoshLockscreenManager *self)
{'''),
(
'''  phosh_lockscreen_set_bg_image (self->lockscreen, self->cached_bg_image);

  gtk_widget_set_visible (GTK_WIDGET (self->lockscreen), TRUE);
''',
'''  phosh_lockscreen_set_bg_image (self->lockscreen, self->cached_bg_image);
  g_signal_connect_object (self->lockscreen, "destroy",
                           G_CALLBACK (on_lockscreen_destroyed), self,
                           G_CONNECT_SWAPPED);

  gtk_widget_set_visible (GTK_WIDGET (self->lockscreen), TRUE);
  if (!self->lockscreen)
    return;
'''),
])
