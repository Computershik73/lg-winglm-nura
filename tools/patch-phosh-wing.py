import sys, os

top = sys.argv[1]   # phosh source dir
which = sys.argv[2]  # rotation | move | grid


def edit(name, pairs):
    p = os.path.join(top, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r" % (name, old[:70])
        s = s.replace(old, new)
    open(p, "w").write(s)


# ======================================================================= rotation
if which == "rotation":
    edit("data/mobi.phosh.shell.gschema.xml", [(
'''        Setting this to false allows unlocking without entering the PIN
        or password by simply swiping up.
      </description>
    </key>
  </schema>''',
'''        Setting this to false allows unlocking without entering the PIN
        or password by simply swiping up.
      </description>
    </key>

    <key name="force-portrait" type="b">
      <default>true</default>
      <summary>Turn phones to portrait while locked</summary>
      <description>
        The lock screen doesn't fit a landscape phone screen, so phones
        are turned to portrait when locking and back on unlock. Devices
        whose orientation is managed otherwise (e.g. by a swivel screen)
        set this to false.
      </description>
    </key>
  </schema>''')])

    edit("src/rotation-manager.c", [
('''  GSettings               *settings;
  gboolean                 orientation_locked;''',
'''  GSettings               *settings;
  GSettings               *lockscreen_settings;
  gboolean                 orientation_locked;'''),
# don't force anything when disabled; nothing saved -> nothing to restore
('''  if (lock) {
    if (self->prelock_transform == -1) {''',
'''  if (lock) {
    if (!g_settings_get_boolean (self->lockscreen_settings, "force-portrait"))
      return;

    if (self->prelock_transform == -1) {'''),
('''    if (self->prelock_transform == -1) {
      g_warning ("Prelock transform invalid");
      self->prelock_transform = PHOSH_MONITOR_TRANSFORM_NORMAL;
    }''',
'''    /* Nothing forced on lock (or it was already restored) */
    if (self->prelock_transform == -1)
      return;'''),
('''phosh_rotation_manager_init (PhoshRotationManager *self)
{
  self->cancel = g_cancellable_new ();''',
'''phosh_rotation_manager_init (PhoshRotationManager *self)
{
  self->cancel = g_cancellable_new ();
  /* 0 is a valid transform: without this the first unlock "restored" portrait */
  self->prelock_transform = -1;
  self->lockscreen_settings = g_settings_new ("sm.puri.phosh.lockscreen");'''),
('''  g_clear_object (&self->settings);''',
'''  g_clear_object (&self->settings);
  g_clear_object (&self->lockscreen_settings);'''),
])
    print("patched rotation")
    sys.exit(0)

# ======================================================================= move
if which == "move":
    # protocol: phoc's copy (v8) plus the v9 request; written by the caller
    edit("src/phosh-wayland.c", [(
'''    self->phosh_private = wl_registry_bind (registry,
                                            name,
                                            &phosh_private_interface,
                                            7);''',
'''    /* v9 adds move_toplevel_to_output, stay at 7 for older compositors */
    self->phosh_private = wl_registry_bind (registry,
                                            name,
                                            &phosh_private_interface,
                                            version >= 9 ? 9 : 7);''')])

    edit("src/toplevel.h", [(
'''void phosh_toplevel_close (PhoshToplevel *self);''',
'''void phosh_toplevel_close (PhoshToplevel *self);
gboolean phosh_toplevel_move_to_next_output (PhoshToplevel *self);''')])

    edit("src/toplevel.c", [(
'''void
phosh_toplevel_close (PhoshToplevel *self)
{''',
'''/**
 * phosh_toplevel_move_to_next_output:
 * @self: The toplevel
 *
 * Ask the compositor to move the toplevel to the next output.
 *
 * Returns: %FALSE if the compositor can't do that
 */
gboolean
phosh_toplevel_move_to_next_output (PhoshToplevel *self)
{
  PhoshWayland *wl = phosh_wayland_get_default ();
  struct phosh_private *phosh_private = phosh_wayland_get_phosh_private (wl);

  g_return_val_if_fail (PHOSH_IS_TOPLEVEL (self), FALSE);

  if (!phosh_private || phosh_wayland_get_phosh_private_version (wl) < 9)
    return FALSE;

  phosh_private_move_toplevel_to_output (phosh_private, self->handle, NULL);
  return TRUE;
}


void
phosh_toplevel_close (PhoshToplevel *self)
{''')])

    edit("src/activity.h", [(
'''GAppInfo *  phosh_activity_get_app_info (PhoshActivity *self);''',
'''GAppInfo *  phosh_activity_get_app_info (PhoshActivity *self);
void        phosh_activity_set_movable (PhoshActivity *self, gboolean movable);''')])

    edit("src/ui/activity.ui", [(
'''                <child type="overlay">
                  <object class="GtkSpinner" id="spinner">''',
'''                <child type="overlay">
                  <object class="GtkRevealer" id="revealer_move">
                    <property name="transition-type">crossfade</property>
                    <property name="visible" bind-source="revealer_move" bind-property="child-revealed" bind-flags="sync-create"/>
                    <property name="halign">end</property>
                    <property name="valign">end</property>
                    <child>
                      <object class="GtkButton" id="btn_move">
                        <property name="visible">1</property>
                        <property name="tooltip-text" translatable="yes">Move to the other screen</property>
                        <signal name="clicked" handler="on_move_clicked" swapped="true"/>
                        <child>
                          <object class="GtkImage">
                            <property name="visible">1</property>
                            <property name="pixel-size">24</property>
                            <property name="icon-name">view-dual-symbolic</property>
                          </object>
                        </child>
                        <style>
                          <class name="phosh-activity-close-button"/>
                          <class name="osd"/>
                        </style>
                      </object>
                    </child>
                  </object>
                  <packing>
                    <property name="pass-through">1</property>
                    <property name="index">1</property>
                  </packing>
                </child>
                <child type="overlay">
                  <object class="GtkSpinner" id="spinner">''')])

    edit("src/activity.c", [
('''  CLOSED,
  FULLSCREENED,
  RESIZED,
  N_SIGNALS''',
'''  CLOSED,
  FULLSCREENED,
  RESIZED,
  MOVE_REQUESTED,
  N_SIGNALS'''),
('''  GtkWidget       *revealer_unfullscreen;
  GtkWidget       *btn_close;''',
'''  GtkWidget       *revealer_unfullscreen;
  GtkWidget       *revealer_move;
  GtkWidget       *btn_close;'''),
('''static void
on_unfullscreen_clicked (PhoshActivity *self)
{''',
'''static void
on_move_clicked (PhoshActivity *self)
{
  g_signal_emit (self, signals[MOVE_REQUESTED], 0);
}


static void
on_unfullscreen_clicked (PhoshActivity *self)
{'''),
('''  signals[RESIZED] = g_signal_new ("resized",''',
'''  /**
   * PhoshActivity::move-requested
   * @self: The activity
   *
   * The user wants the activity on another screen.
   */
  signals[MOVE_REQUESTED] = g_signal_new ("move-requested",
                                          G_TYPE_FROM_CLASS (klass),
                                          G_SIGNAL_RUN_LAST, 0, NULL, NULL,
                                          NULL,
                                          G_TYPE_NONE,
                                          0);

  signals[RESIZED] = g_signal_new ("resized",'''),
('''  gtk_widget_class_bind_template_child_private (widget_class, PhoshActivity, revealer_unfullscreen);''',
'''  gtk_widget_class_bind_template_child_private (widget_class, PhoshActivity, revealer_unfullscreen);
  gtk_widget_class_bind_template_child_private (widget_class, PhoshActivity, revealer_move);'''),
('''  gtk_widget_class_bind_template_callback (widget_class, on_unfullscreen_clicked);''',
'''  gtk_widget_class_bind_template_callback (widget_class, on_unfullscreen_clicked);
  gtk_widget_class_bind_template_callback (widget_class, on_move_clicked);'''),
])
    # setter at the end of the file
    p = os.path.join(top, "src/activity.c")
    s = open(p).read()
    s += '''

/**
 * phosh_activity_set_movable:
 * @self: The activity
 * @movable: Whether to offer moving the activity to another screen
 *
 * Shows or hides the button to move the activity to another screen.
 */
void
phosh_activity_set_movable (PhoshActivity *self, gboolean movable)
{
  PhoshActivityPrivate *priv;

  g_return_if_fail (PHOSH_IS_ACTIVITY (self));
  priv = phosh_activity_get_instance_private (self);

  /* Revealer won't animate if not mapped, show it preemptively */
  if (movable)
    gtk_widget_set_visible (priv->revealer_move, TRUE);
  gtk_revealer_set_reveal_child (GTK_REVEALER (priv->revealer_move), movable);
}
'''
    open(p, "w").write(s)

    edit("src/overview.c", [
('''#include "phosh-wayland.h"''', '''#include "phosh-wayland.h"
#include "monitor-manager.h"'''),
('''static void
on_activity_closed (PhoshOverview *self, PhoshActivity *activity)''',
'''static gboolean
can_move_activities (void)
{
  PhoshMonitorManager *mm = phosh_shell_get_monitor_manager (phosh_shell_get_default ());

  return mm && phosh_monitor_manager_get_num_monitors (mm) > 1;
}


static void
on_n_monitors_changed (PhoshOverview *self)
{
  PhoshOverviewPrivate *priv = phosh_overview_get_instance_private (self);
  g_autoptr (GList) children = NULL;
  gboolean movable = can_move_activities ();

  children = gtk_container_get_children (GTK_CONTAINER (priv->carousel_running_activities));
  for (GList *l = children; l; l = l->next) {
    if (PHOSH_IS_ACTIVITY (l->data))
      phosh_activity_set_movable (PHOSH_ACTIVITY (l->data), movable);
  }
}


static void on_activity_clicked (PhoshOverview *self, PhoshActivity *activity);

/* Send the window to the other screen and show it there */
static void
on_activity_move_requested (PhoshOverview *self, PhoshActivity *activity)
{
  PhoshToplevel *toplevel = phosh_overview_get_toplevel_from_activity (self, activity);

  if (!toplevel)
    return;

  g_debug ("Moving %s to the next output", phosh_activity_get_app_id (activity));
  if (!phosh_toplevel_move_to_next_output (toplevel)) {
    g_warning ("Compositor can't move windows between screens");
    return;
  }
  on_activity_clicked (self, activity);
}


static void
on_activity_closed (PhoshOverview *self, PhoshActivity *activity)'''),
('''                    "swapped-signal::resized", on_activity_resized, self,
                    NULL);''',
'''                    "swapped-signal::resized", on_activity_resized, self,
                    "swapped-signal::move-requested", on_activity_move_requested, self,
                    NULL);
  phosh_activity_set_movable (PHOSH_ACTIVITY (activity), can_move_activities ());'''),
])
    # connect to the monitor count once the overview is set up
    p = os.path.join(top, "src/overview.c")
    s = open(p).read()
    anchor = "  priv->has_activities = -1;\n"
    assert s.count(anchor) == 1
    s = s.replace(anchor, anchor + '''
  g_signal_connect_object (phosh_shell_get_monitor_manager (phosh_shell_get_default ()),
                           "notify::n-monitors",
                           G_CALLBACK (on_n_monitors_changed),
                           self,
                           G_CONNECT_SWAPPED);
''')
    open(p, "w").write(s)
    print("patched move")
    sys.exit(0)

# ======================================================================= grid
if which == "grid":
    edit("src/home.c", [
('''#include "osk-manager.h"''', '''#include "osk-manager.h"
#include "monitor-manager.h"'''),
('''  gboolean         unfolding;
''',
'''  gboolean         unfolding;

  /* App grid on a second built-in screen while the main one is landscape
   * (LG Wing T position): the main screen keeps the running apps */
  GtkWidget       *grid_home;    /* the app grid's place in the overview */
  GtkWidget       *grid_surface; /* layer surface on grid_monitor */
  PhoshMonitor    *grid_monitor;
'''),
('''static gboolean
on_configure_event (PhoshHome *self, GdkEventConfigure *event)
{''',
'''static void update_app_grid_placement (PhoshHome *self);


static void
move_widget (GtkWidget *widget, GtkWidget *target)
{
  GtkWidget *parent = gtk_widget_get_parent (widget);

  if (parent == target)
    return;

  g_object_ref (widget);
  if (parent)
    gtk_container_remove (GTK_CONTAINER (parent), widget);
  gtk_container_add (GTK_CONTAINER (target), widget);
  g_object_unref (widget);
}


/* The second built-in screen while the main one is landscape */
static PhoshMonitor *
find_grid_monitor (PhoshHome *self)
{
  PhoshShell *shell = phosh_shell_get_default ();
  PhoshMonitorManager *mm = phosh_shell_get_monitor_manager (shell);
  PhoshMonitor *primary = phosh_shell_get_primary_monitor (shell);

  if (!primary || !mm || primary->logical.width <= primary->logical.height)
    return NULL;

  for (guint i = 0; i < phosh_monitor_manager_get_num_monitors (mm); i++) {
    PhoshMonitor *monitor = phosh_monitor_manager_get_monitor (mm, i);

    if (!monitor || monitor == primary || !monitor->name ||
        !phosh_monitor_is_configured (monitor))
      continue;

    if (phosh_monitor_is_builtin (monitor))
      return monitor;
  }

  return NULL;
}


static void
on_grid_surface_destroy (PhoshHome *self, GtkWidget *surface)
{
  GtkWidget *app_grid = GTK_WIDGET (phosh_overview_get_app_grid (self->overview));

  /* Closed by the compositor (its output went away): save the app grid */
  if (gtk_widget_get_parent (app_grid) == surface)
    move_widget (app_grid, self->grid_home);

  if (self->grid_surface == surface)
    self->grid_surface = NULL;
  g_clear_object (&self->grid_monitor);
}


static void
destroy_grid_surface (PhoshHome *self)
{
  GtkWidget *surface = g_steal_pointer (&self->grid_surface);
  GtkWidget *app_grid;

  if (!surface)
    return;

  app_grid = GTK_WIDGET (phosh_overview_get_app_grid (self->overview));

  g_signal_handlers_disconnect_by_data (surface, self);
  if (gtk_widget_get_parent (app_grid) == surface)
    move_widget (app_grid, self->grid_home);
  gtk_widget_destroy (surface);
  g_clear_object (&self->grid_monitor);
}


static void
create_grid_surface (PhoshHome *self, PhoshMonitor *monitor)
{
  static GtkCssProvider *provider;
  PhoshWayland *wl = phosh_wayland_get_default ();
  GtkStyleContext *context;

  if (!provider) {
    provider = gtk_css_provider_new ();
    gtk_css_provider_load_from_data (provider,
                                     ".phosh-app-grid-surface { background-color: rgba(0, 0, 0, 0.85); }",
                                     -1, NULL);
  }

  g_debug ("App grid goes to %s", monitor->name);
  self->grid_monitor = g_object_ref (monitor);
  self->grid_surface = g_object_new (PHOSH_TYPE_LAYER_SURFACE,
                                     "layer-shell", phosh_wayland_get_zwlr_layer_shell_v1 (wl),
                                     "wl-output", monitor->wl_output,
                                     "anchor", ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
                                               ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                                               ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                                               ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
                                     "layer", ZWLR_LAYER_SHELL_V1_LAYER_TOP,
                                     "kbd-interactivity", TRUE,
                                     "exclusive-zone", 0,
                                     "namespace", "phosh app grid",
                                     NULL);
  context = gtk_widget_get_style_context (self->grid_surface);
  gtk_style_context_add_provider (context, GTK_STYLE_PROVIDER (provider),
                                  GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  gtk_style_context_add_class (context, "phosh-app-grid-surface");
  g_signal_connect_object (self->grid_surface, "destroy",
                           G_CALLBACK (on_grid_surface_destroy), self,
                           G_CONNECT_SWAPPED);
}


/* Put the app grid on the second screen in the T position, show it while
 * the home is unfolded */
static void
update_app_grid_placement (PhoshHome *self)
{
  GtkWidget *app_grid;
  PhoshMonitor *monitor;
  gboolean show;

  if (!self->overview || !self->grid_home)
    return;

  app_grid = GTK_WIDGET (phosh_overview_get_app_grid (self->overview));
  monitor = find_grid_monitor (self);

  if (self->grid_surface && monitor != self->grid_monitor)
    destroy_grid_surface (self);

  if (monitor && !self->grid_surface)
    create_grid_surface (self, monitor);

  move_widget (app_grid, self->grid_surface ?: self->grid_home);

  if (!self->grid_surface)
    return;

  show = self->state == PHOSH_HOME_STATE_UNFOLDED && gtk_widget_get_visible (GTK_WIDGET (self));
  gtk_widget_set_visible (self->grid_surface, show);
  /* the grid surface gets the keyboard (search) instead of the home */
  phosh_layer_surface_set_kbd_interactivity (PHOSH_LAYER_SURFACE (self), FALSE);
}


static void
on_monitor_added (PhoshHome *self, PhoshMonitor *monitor)
{
  /* name and connector type come with a later 'configured' */
  g_signal_connect_object (monitor, "configured",
                           G_CALLBACK (update_app_grid_placement), self,
                           G_CONNECT_SWAPPED);
  update_app_grid_placement (self);
}


static void
on_monitor_removed (PhoshHome *self, PhoshMonitor *monitor)
{
  if (monitor == self->grid_monitor)
    destroy_grid_surface (self);
  update_app_grid_placement (self);
}


static gboolean
on_configure_event (PhoshHome *self, GdkEventConfigure *event)
{'''),
('''  /* Update drag handle since overview size might have changed */
  update_drag_handle (self, TRUE);

  return FALSE;
}''',
'''  /* Update drag handle since overview size might have changed */
  update_drag_handle (self, TRUE);

  /* Rotated: the app grid may move between the screens */
  update_app_grid_placement (self);

  return FALSE;
}'''),
('''  phosh_layer_surface_set_kbd_interactivity (PHOSH_LAYER_SURFACE (self), kbd_interactivity);
  update_drag_handle (self, TRUE);
}''',
'''  phosh_layer_surface_set_kbd_interactivity (PHOSH_LAYER_SURFACE (self), kbd_interactivity);
  update_drag_handle (self, TRUE);
  update_app_grid_placement (self);
}'''),
])

    # constructed: remember the grid's home and watch the monitors
    p = os.path.join(top, "src/home.c")
    s = open(p).read()
    i = s.index("\nphosh_home_constructed (GObject *object)\n")
    j = s.index("\n}\n", i)
    body = s[i:j]
    assert "G_OBJECT_CLASS (phosh_home_parent_class)->constructed (object);" in body, body
    s = s[:j] + '''

  self->grid_home = gtk_widget_get_parent (GTK_WIDGET (phosh_overview_get_app_grid (self->overview)));
  g_signal_connect_object (phosh_shell_get_monitor_manager (phosh_shell_get_default ()),
                           "monitor-added", G_CALLBACK (on_monitor_added), self,
                           G_CONNECT_SWAPPED);
  g_signal_connect_object (phosh_shell_get_monitor_manager (phosh_shell_get_default ()),
                           "monitor-removed", G_CALLBACK (on_monitor_removed), self,
                           G_CONNECT_SWAPPED);
  g_signal_connect (self, "notify::visible", G_CALLBACK (update_app_grid_placement), NULL);
  update_app_grid_placement (self);''' + s[j:]
    # dispose: put the grid back before the overview goes
    i = s.index("\nphosh_home_dispose (GObject *object)\n")
    k = s.index("{\n", i) + 2
    decl_end = s.index("\n\n", k) + 1  # after the local declarations
    s = s[:decl_end] + '''
  destroy_grid_surface (self);
''' + s[decl_end:]
    open(p, "w").write(s)
    print("patched grid")
    sys.exit(0)

raise SystemExit("unknown patch " + which)
