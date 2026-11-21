import sys, os

src = sys.argv[1]  # phosh src/ dir


def edit(name, pairs):
    p = os.path.join(src, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r" % (name, old[:60])
        s = s.replace(old, new)
    open(p, "w").write(s)


# ---------------------------------------------------------------- lockscreen.h
edit("lockscreen.h", [(
'''void                phosh_lockscreen_add_extra_page (PhoshLockscreen *self, GtkWidget *widget);
''',
'''void                phosh_lockscreen_add_extra_page (PhoshLockscreen *self, GtkWidget *widget);

void                phosh_lockscreen_set_keypad_container (PhoshLockscreen *self,
                                                           GtkContainer    *container);
''')])

# ---------------------------------------------------------------- lockscreen.c
edit("lockscreen.c", [
(
'''  GtkWidget          *btn_keyboard;
  guint idle_timer;''',
'''  GtkWidget          *btn_keyboard;
  GtkWidget          *keypad_container; /* where the keypad should go, if anywhere */
  gboolean            keypad_external;  /* the keypad is there right now */
  guint idle_timer;'''),
(
'''  g_object_bind_property (self, "require-unlock",
                          priv->box_unlock, "visible",
                          G_BINDING_SYNC_CREATE);''',
'''  g_object_bind_property (self, "require-unlock",
                          priv->box_unlock, "visible",
                          G_BINDING_SYNC_CREATE);
  /* a keypad on another screen follows the unlock box (greeters show it
   * only once a user is picked) */
  g_signal_connect_object (priv->box_unlock, "notify::visible",
                           G_CALLBACK (apply_keypad_placement), self,
                           G_CONNECT_SWAPPED);'''),
(
'''  length = gtk_entry_get_text_length (GTK_ENTRY (priv->entry_pin));

  gtk_widget_set_sensitive (priv->btn_submit, length != 0);
}
''',
'''  length = gtk_entry_get_text_length (GTK_ENTRY (priv->entry_pin));

  gtk_widget_set_sensitive (priv->btn_submit, length != 0);

  /* The keypad sits on another screen and stays usable on every page:
   * show the entry it types into */
  if (priv->keypad_external && length != 0 &&
      phosh_lockscreen_get_page (self) != PHOSH_LOCKSCREEN_PAGE_UNLOCK)
    show_unlock_page (self);
}
'''),
(
'''static void
phosh_lockscreen_dispose (GObject *object)
{
  PhoshLockscreen *self = PHOSH_LOCKSCREEN (object);
  PhoshLockscreenPrivate *priv = phosh_lockscreen_get_instance_private (self);
''',
'''static void
phosh_lockscreen_dispose (GObject *object)
{
  PhoshLockscreen *self = PHOSH_LOCKSCREEN (object);
  PhoshLockscreenPrivate *priv = phosh_lockscreen_get_instance_private (self);

  /* The keypad may be on another screen: bring it back before the entry
   * it types into goes away, and stop following that screen */
  if (priv->keypad_container) {
    g_signal_handlers_disconnect_by_func (priv->keypad_container,
                                          on_keypad_container_destroy, self);
    priv->keypad_container = NULL;
  }
  if (priv->keypad_external)
    apply_keypad_placement (self);
'''),
(
'''G_DEFINE_TYPE_WITH_PRIVATE (PhoshLockscreen, phosh_lockscreen, PHOSH_TYPE_LAYER_SURFACE)''',
'''G_DEFINE_TYPE_WITH_PRIVATE (PhoshLockscreen, phosh_lockscreen, PHOSH_TYPE_LAYER_SURFACE)

static void apply_keypad_placement (PhoshLockscreen *self);
static void on_keypad_container_destroy (PhoshLockscreen *self);'''),
(
'''void
phosh_lockscreen_add_extra_page (PhoshLockscreen *self, GtkWidget *widget)''',
'''/* Put the keypad and the unlock button where they belong now: in the
 * requested container while the unlock box is shown, on the lockscreen
 * otherwise (greeters hide the unlock box until a user is picked). */
static void
apply_keypad_placement (PhoshLockscreen *self)
{
  PhoshLockscreenPrivate *priv = phosh_lockscreen_get_instance_private (self);
  GtkWidget *container = NULL, *submit_box, *keypad_target, *submit_target;

  if (priv->keypad_container && gtk_widget_get_visible (priv->box_unlock))
    container = priv->keypad_container;

  keypad_target = container ?: priv->keypad_revealer;
  submit_target = container ?: priv->box_unlock;
  if (gtk_widget_get_parent (priv->keypad) == keypad_target)
    return;

  g_debug ("Keypad moves to %s", container ? "another screen" : "the lockscreen");
  submit_box = gtk_widget_get_parent (priv->btn_submit);

  g_object_ref (priv->keypad);
  g_object_ref (submit_box);
  gtk_container_remove (GTK_CONTAINER (gtk_widget_get_parent (priv->keypad)), priv->keypad);
  gtk_container_remove (GTK_CONTAINER (gtk_widget_get_parent (submit_box)), submit_box);
  /* keypad first, unlock button below it, as on the lockscreen */
  gtk_container_add (GTK_CONTAINER (keypad_target), priv->keypad);
  gtk_container_add (GTK_CONTAINER (submit_target), submit_box);
  g_object_unref (submit_box);
  g_object_unref (priv->keypad);

  priv->keypad_external = container != NULL;
  gtk_widget_set_visible (priv->keypad_revealer, !priv->keypad_external);
}


static void
on_keypad_container_destroy (PhoshLockscreen *self)
{
  PhoshLockscreenPrivate *priv = phosh_lockscreen_get_instance_private (self);

  /* The other screen went away (output disabled, layer surface closed):
   * take the keypad back before its container destroys it */
  priv->keypad_container = NULL;
  apply_keypad_placement (self);
}


/**
 * phosh_lockscreen_set_keypad_container:
 * @self: The lockscreen
 * @container: (nullable): Where to show the keypad and the unlock button, or
 *   %NULL to keep them on the lockscreen
 *
 * Devices with a second screen below a main screen turned to landscape
 * (LG Wing in its T position) have no room for the keypad on the lock
 * screen. Show the keypad and the unlock button on the other screen
 * instead, whenever the unlock box is shown; the keypad keeps typing into
 * the PIN entry of the lockscreen.
 */
void
phosh_lockscreen_set_keypad_container (PhoshLockscreen *self, GtkContainer *container)
{
  PhoshLockscreenPrivate *priv;

  g_return_if_fail (PHOSH_IS_LOCKSCREEN (self));
  g_return_if_fail (container == NULL || GTK_IS_CONTAINER (container));
  priv = phosh_lockscreen_get_instance_private (self);

  if (priv->keypad_container != GTK_WIDGET (container)) {
    if (priv->keypad_container)
      g_signal_handlers_disconnect_by_func (priv->keypad_container,
                                            on_keypad_container_destroy, self);
    priv->keypad_container = GTK_WIDGET (container);
    if (container)
      g_signal_connect_object (container, "destroy",
                               G_CALLBACK (on_keypad_container_destroy), self,
                               G_CONNECT_SWAPPED);
  }
  apply_keypad_placement (self);
}


void
phosh_lockscreen_add_extra_page (PhoshLockscreen *self, GtkWidget *widget)'''),
])

# ---------------------------------------------------------------- lockshield.h
edit("lockshield.h", [(
'''GtkWidget *phosh_lockshield_new (struct zwlr_layer_shell_v1 *layer_shell,
                                 PhoshMonitor               *monitor);''',
'''GtkWidget *phosh_lockshield_new (struct zwlr_layer_shell_v1 *layer_shell,
                                 PhoshMonitor               *monitor);
GtkContainer *phosh_lockshield_get_keypad_box (PhoshLockshield *self);''')])

# ---------------------------------------------------------------- lockshield.c
edit("lockshield.c", [
(
'''struct _PhoshLockshield
{
  PhoshLayerSurface parent;
};''',
'''struct _PhoshLockshield
{
  PhoshLayerSurface parent;

  GtkWidget        *keypad_box;  /* the lockscreen keypad may move here */
};'''),
(
'''static void
phosh_lockshield_init (PhoshLockshield *self)
{
}''',
'''static void
phosh_lockshield_init (PhoshLockshield *self)
{
  self->keypad_box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 12);
  gtk_widget_set_halign (self->keypad_box, GTK_ALIGN_CENTER);
  gtk_widget_set_valign (self->keypad_box, GTK_ALIGN_CENTER);
  gtk_widget_set_visible (self->keypad_box, TRUE);
  gtk_container_add (GTK_CONTAINER (self), self->keypad_box);
}


/**
 * phosh_lockshield_get_keypad_box:
 * @self: The lock shield
 *
 * Returns: (transfer none): The container the lockscreen keypad can be
 *   moved to when the main screen has no room for it
 */
GtkContainer *
phosh_lockshield_get_keypad_box (PhoshLockshield *self)
{
  g_return_val_if_fail (PHOSH_IS_LOCKSHIELD (self), NULL);

  return GTK_CONTAINER (self->keypad_box);
}'''),
])

# ------------------------------------------------------- lockscreen-manager.c
edit("lockscreen-manager.c", [
(
'''#include "lockshield.h"''',
'''#include "lockshield.h"
#include "layersurface-priv.h"'''),
(
'''  gboolean                 locked;
  gboolean                 locking;''',
'''  gboolean                 locked;
  gboolean                 locking;
  gboolean                 shields_teardown; /* we destroy the shields ourselves */'''),
# the compositor may close a shield (output disabled) before the monitor is
# reported as removed: drop it from the list instead of keeping a dangling
# pointer around
(
'''/* Lock a non primary monitor bringing up a shield */
static void
lock_monitor (PhoshLockscreenManager *self,
              PhoshMonitor           *monitor)''',
'''static void
on_shield_destroyed (PhoshLockscreenManager *self, GtkWidget *shield)
{
  guint index;

  if (self->shields_teardown || !self->shields)
    return;

  if (g_ptr_array_find (self->shields, shield, &index)) {
    g_debug ("Shield %p closed by the compositor", shield);
    g_ptr_array_steal_index (self->shields, index);
  }
}


/* Lock a non primary monitor bringing up a shield */
static void
lock_monitor (PhoshLockscreenManager *self,
              PhoshMonitor           *monitor)'''),
(
'''  /* Primary monitor is handled via on_primary_monitor_changed */
  if (phosh_shell_get_primary_monitor (shell) == monitor)
    return;
''',
'''  /* Primary monitor is handled via on_primary_monitor_changed */
  if (phosh_shell_get_primary_monitor (shell) == monitor)
    return;

  /* One shield per monitor: a second one would cover the first (and the
   * keypad that may be in it) */
  for (guint i = 0; i < self->shields->len; i++) {
    GtkWidget *other = g_ptr_array_index (self->shields, i);

    if (g_object_get_data (G_OBJECT (other), "phosh-monitor") == monitor &&
        !gtk_widget_in_destruction (other)) {
      g_debug ("Monitor %p already has shield %p", monitor, other);
      return;
    }
  }
'''),
(
'''  g_object_set_data (G_OBJECT (shield), "phosh-monitor", monitor);''',
'''  /* Keep the monitor alive as long as its shield: an output switched off
   * and on quickly (LG Wing swivel) can drop the monitor before its shield
   * is removed, leaving a dangling pointer here */
  g_object_set_data_full (G_OBJECT (shield), "phosh-monitor", g_object_ref (monitor),
                          g_object_unref);'''),
(
'''  g_ptr_array_add (self->shields, shield);
  gtk_widget_set_visible (shield, TRUE);''',
'''  g_ptr_array_add (self->shields, shield);
  g_signal_connect_object (shield, "destroy", G_CALLBACK (on_shield_destroyed), self,
                           G_CONNECT_SWAPPED);
  /* re-check once the shield is on its output and that output fully known */
  g_signal_connect_object (shield, "configured", G_CALLBACK (update_keypad_placement), self,
                           G_CONNECT_SWAPPED);
  gtk_widget_set_visible (shield, TRUE);'''),
(
'''  /* Unlock all other outputs */
  g_clear_pointer (&self->shields, g_ptr_array_unref);''',
'''  /* Unlock all other outputs */
  self->shields_teardown = TRUE;
  g_clear_pointer (&self->shields, g_ptr_array_unref);
  self->shields_teardown = FALSE;'''),
(
'''static void
on_lockscreen_wakeup_output (PhoshLockscreenManager *self, PhoshLockscreen *lockscreen)''',
'''/*
 * A main screen turned to landscape has no room for the lockscreen keypad.
 * If another built-in screen shows a shield (LG Wing in its T position, the
 * swivel screen below the main one), show the keypad there.
 */
static gboolean
monitor_is_current (PhoshMonitor *monitor)
{
  PhoshShell *shell = phosh_shell_get_default ();
  PhoshMonitorManager *mm = phosh_shell_get_monitor_manager (shell);

  for (guint i = 0; i < phosh_monitor_manager_get_num_monitors (mm); i++) {
    if (phosh_monitor_manager_get_monitor (mm, i) == monitor)
      return TRUE;
  }
  return FALSE;
}


/* Drop shields of monitors that are gone: an output switched off and on
 * quickly may leave one behind that never got a monitor-removed */
static void
prune_stale_shields (PhoshLockscreenManager *self)
{
  if (!self->shields)
    return;

  for (gint i = (gint) self->shields->len - 1; i >= 0; i--) {
    GtkWidget *shield = g_ptr_array_index (self->shields, i);
    PhoshMonitor *monitor = g_object_get_data (G_OBJECT (shield), "phosh-monitor");

    if (PHOSH_IS_MONITOR (monitor) && monitor_is_current (monitor))
      continue;

    g_debug ("Removing stale shield %p", shield);
    if (self->lockscreen)
      phosh_lockscreen_set_keypad_container (self->lockscreen, NULL);
    self->shields_teardown = TRUE;
    g_ptr_array_remove_index (self->shields, i);
    self->shields_teardown = FALSE;
  }
}


static void
update_keypad_placement (PhoshLockscreenManager *self)
{
  PhoshLayerSurface *surface;
  PhoshLockshield *target = NULL;
  int width, height;

  if (!self->lockscreen)
    return;

  prune_stale_shields (self);

  /* Judge by the lockscreen's own size: monitors only report their
   * transform once, the lockscreen gets reconfigured when the screen turns */
  surface = PHOSH_LAYER_SURFACE (self->lockscreen);
  width = phosh_layer_surface_get_configured_width (surface);
  height = phosh_layer_surface_get_configured_height (surface);

  if (self->shields && width > height) {
    for (guint i = 0; i < self->shields->len; i++) {
      PhoshLockshield *shield = g_ptr_array_index (self->shields, i);
      PhoshMonitor *monitor = g_object_get_data (G_OBJECT (shield), "phosh-monitor");

      if (gtk_widget_in_destruction (GTK_WIDGET (shield)) || !PHOSH_IS_MONITOR (monitor))
        continue;

      g_debug ("keypad: lockscreen %dx%d, shield %p on %s (conn %d, mapped %d)",
               width, height, shield, monitor->name ?: "?", monitor->conn_type,
               gtk_widget_get_mapped (GTK_WIDGET (shield)));

      /* A freshly added monitor may not know its connector yet (the name
       * comes later): only skip screens known to be external */
      if (monitor->conn_type == PHOSH_MONITOR_CONNECTOR_TYPE_Unknown ||
          phosh_monitor_is_builtin (monitor)) {
        target = shield;
        break;
      }
    }
  }

  phosh_lockscreen_set_keypad_container (self->lockscreen,
                                         target ? phosh_lockshield_get_keypad_box (target) : NULL);
}


static void
on_lockscreen_wakeup_output (PhoshLockscreenManager *self, PhoshLockscreen *lockscreen)'''),
# unlock: put the keypad back before the lockscreen and shields go away
(
'''  g_signal_handlers_disconnect_by_data (shell, self);
  g_clear_pointer (&self->lockscreen, phosh_cp_widget_destroy);''',
'''  g_signal_handlers_disconnect_by_data (shell, self);
  phosh_lockscreen_set_keypad_container (self->lockscreen, NULL);
  g_clear_pointer (&self->lockscreen, phosh_cp_widget_destroy);'''),
# a shield goes away: take the keypad back first
(
'''    if (shield_monitor == monitor) {
      g_debug ("Removing shield %p", shield);
      g_ptr_array_remove (self->shields, shield);
      break;
    }
  }
}''',
'''    if (shield_monitor == monitor) {
      g_debug ("Removing shield %p", shield);
      if (self->lockscreen)
        phosh_lockscreen_set_keypad_container (self->lockscreen, NULL);
      self->shields_teardown = TRUE;
      g_ptr_array_remove (self->shields, shield);
      self->shields_teardown = FALSE;
      break;
    }
  }
  update_keypad_placement (self);
}'''),
(
'''  g_debug ("Monitor '%s' added", monitor->name);
  lock_monitor (self, monitor);
}''',
'''  g_debug ("Monitor '%s' added", monitor->name);
  lock_monitor (self, monitor);
  update_keypad_placement (self);
}'''),
# a new lockscreen replaces the old one: take the keypad back from the old one
(
'''  primary_monitor = phosh_shell_get_primary_monitor (shell);
  g_assert (PHOSH_IS_MONITOR (primary_monitor));

  /* The primary output gets the clock, keypad, ... */''',
'''  primary_monitor = phosh_shell_get_primary_monitor (shell);
  g_assert (PHOSH_IS_MONITOR (primary_monitor));

  if (self->lockscreen)
    phosh_lockscreen_set_keypad_container (self->lockscreen, NULL);

  /* The primary output gets the clock, keypad, ... */'''),
(
'''  gtk_widget_set_visible (GTK_WIDGET (self->lockscreen), TRUE);
  /* Old lockscreen gets remove due to `layer_surface_closed` */
}''',
'''  gtk_widget_set_visible (GTK_WIDGET (self->lockscreen), TRUE);
  /* Old lockscreen gets remove due to `layer_surface_closed` */

  /* The main screen may turn while locked (swivel opened): the lockscreen
   * gets a new size then */
  g_signal_connect_object (self->lockscreen, "configured",
                           G_CALLBACK (update_keypad_placement), self,
                           G_CONNECT_SWAPPED);
  update_keypad_placement (self);
}'''),
# after locking all outputs
(
'''    if (monitor == NULL || monitor == primary_monitor)
      continue;
    lock_monitor (self, monitor);
  }
''',
'''    if (monitor == NULL || monitor == primary_monitor)
      continue;
    lock_monitor (self, monitor);
  }
  update_keypad_placement (self);
'''),
])
print("patched")
