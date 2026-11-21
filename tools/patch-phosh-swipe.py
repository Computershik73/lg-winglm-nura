import os
import sys

top = sys.argv[1]   # phosh source dir with 0006 applied


def edit(name, pairs, count=1):
    p = os.path.join(top, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == count, "%s: %r" % (name, old[:70])
        s = s.replace(old, new)
    open(p, "w").write(s)


# The grid surface holds a focusable event box with the app grid inside: it
# takes the focus when the surface is shown, otherwise GTK focuses the first
# focusable widget, the search entry, and the OSK pops up over the grid
edit("src/home.c", [(
'''  if (gtk_widget_get_parent (app_grid) == surface)''',
'''  if (gtk_widget_is_ancestor (app_grid, surface))'''),
], count=2)

edit("src/home.c", [
(
'''  gtk_style_context_add_class (context, "phosh-app-grid-surface");
''',
'''  gtk_style_context_add_class (context, "phosh-app-grid-surface");
  focus = gtk_event_box_new ();
  gtk_widget_set_can_focus (focus, TRUE);
  gtk_widget_show (focus);
  gtk_container_add (GTK_CONTAINER (self->grid_surface), focus);
'''),
(
'''  PhoshWayland *wl = phosh_wayland_get_default ();
  GtkStyleContext *context;
''',
'''  PhoshWayland *wl = phosh_wayland_get_default ();
  GtkStyleContext *context;
  GtkWidget *focus;
'''),
(
'''  move_widget (app_grid, self->grid_surface ?: self->grid_home);''',
'''  move_widget (app_grid, self->grid_surface ?
               gtk_bin_get_child (GTK_BIN (self->grid_surface)) : self->grid_home);'''),
(
'''  gtk_widget_set_visible (self->grid_surface, show);
''',
'''  /* no focus on the search entry (and no OSK) until it's tapped */
  if (show && !gtk_widget_get_visible (self->grid_surface))
    gtk_window_set_focus (GTK_WINDOW (self->grid_surface),
                          gtk_bin_get_child (GTK_BIN (self->grid_surface)));
  gtk_widget_set_visible (self->grid_surface, show);
'''),
])


edit("src/home.c", [
(
'''  PhoshMonitor    *grid_monitor;
};''',
'''  PhoshMonitor    *grid_monitor;
  GtkWidget       *bar_surface;  /* home bar on grid_monitor */
  GtkGesture      *bar_drag;     /* on the bar's event box */
  PhoshMonitor    *removed_monitor; /* going away, still listed */
  gboolean         in_placement;    /* see update_app_grid_placement */
  gboolean         placement_again;
};'''),
(
'''static void
update_app_grid_placement (PhoshHome *self)
{
  GtkWidget *app_grid;''',
'''static void
update_app_grid_placement_once (PhoshHome *self)
{
  GtkWidget *app_grid;'''),
(
'''    if (!monitor || monitor == primary || !monitor->name ||''',
'''    if (!monitor || monitor == primary || monitor == self->removed_monitor ||
        !monitor->name ||'''),
(
'''  if (monitor == self->grid_monitor)
    destroy_grid_surface (self);
  update_app_grid_placement (self);''',
'''  if (monitor == self->grid_monitor)
    destroy_grid_surface (self);
  /* The monitor manager disposes the monitor (its wl_output is gone) before
   * emitting monitor-removed and only drops it from its list afterwards: don't
   * pick it again, a layer surface on a dead wl_output kills the shell */
  self->removed_monitor = monitor;
  update_app_grid_placement (self);
  self->removed_monitor = NULL;'''),
(
'''  GtkWidget *app_grid;

  if (!surface)
    return;

  app_grid = GTK_WIDGET (phosh_overview_get_app_grid (self->overview));
''',
'''  GtkWidget *app_grid;

  destroy_bar_surface (self);

  if (!surface)
    return;

  app_grid = GTK_WIDGET (phosh_overview_get_app_grid (self->overview));
'''),
(
'''static void
destroy_grid_surface (PhoshHome *self)
{''',
'''/* Home bar on the second screen: swipe up opens the overview, swipe down
 * closes it, a tap toggles it, like the home bar on the main screen */
#define SWIVEL_BAR_SWIPE_THRESHOLD 8

static void
on_swivel_bar_drag_end (PhoshHome      *self,
                        double          offset_x,
                        double          offset_y,
                        GtkGestureDrag *gesture)
{
  PhoshHomeState state;

  if (offset_y < -SWIVEL_BAR_SWIPE_THRESHOLD)
    state = PHOSH_HOME_STATE_UNFOLDED;
  else if (offset_y > SWIVEL_BAR_SWIPE_THRESHOLD)
    state = PHOSH_HOME_STATE_FOLDED;
  else if (ABS (offset_x) <= SWIVEL_BAR_SWIPE_THRESHOLD)
    state = !self->state;
  else
    return;

  g_debug ("Second screen home bar: %s",
           state == PHOSH_HOME_STATE_UNFOLDED ? "unfold" : "fold");
  phosh_home_set_state (self, state);
}


/* The gesture goes before the widgets: a GTK3 event controller that
 * outlives its widget touches it when it is finalized */
static void
on_bar_surface_destroy (PhoshHome *self, GtkWidget *surface)
{
  if (self->bar_surface != surface)
    return;

  g_clear_object (&self->bar_drag);
  self->bar_surface = NULL;
}


static void
destroy_bar_surface (PhoshHome *self)
{
  GtkWidget *surface = g_steal_pointer (&self->bar_surface);

  g_clear_object (&self->bar_drag);
  if (!surface)
    return;

  g_signal_handlers_disconnect_by_data (surface, self);
  gtk_widget_destroy (surface);
}


static void
create_bar_surface (PhoshHome *self, PhoshMonitor *monitor)
{
  PhoshWayland *wl = phosh_wayland_get_default ();
  GtkWidget *evbox, *box, *pill;

  destroy_bar_surface (self);
  self->bar_surface = g_object_new (PHOSH_TYPE_LAYER_SURFACE,
                                    "layer-shell", phosh_wayland_get_zwlr_layer_shell_v1 (wl),
                                    "wl-output", monitor->wl_output,
                                    "anchor", ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                                              ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                                              ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
                                    "layer", ZWLR_LAYER_SHELL_V1_LAYER_TOP,
                                    "kbd-interactivity", FALSE,
                                    "exclusive-zone", PHOSH_HOME_BAR_HEIGHT,
                                    "height", PHOSH_HOME_BAR_HEIGHT,
                                    "namespace", "phosh home bar",
                                    NULL);

  /* same widgets and style as the home bar on the main screen */
  evbox = gtk_event_box_new ();
  gtk_widget_set_hexpand (evbox, TRUE);
  gtk_widget_set_size_request (evbox, -1, PHOSH_HOME_BAR_HEIGHT);
  gtk_style_context_add_class (gtk_widget_get_style_context (evbox), "phosh-home-bar");
  gtk_widget_add_events (evbox, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                         GDK_BUTTON_MOTION_MASK | GDK_TOUCH_MASK);
  box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_widget_set_name (box, "home-bar");
  gtk_widget_set_halign (box, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand (box, TRUE);
  pill = gtk_event_box_new ();
  gtk_widget_set_name (pill, "powerbar");
  gtk_widget_set_size_request (pill, 200, PHOSH_HOME_BAR_HEIGHT);
  gtk_widget_set_halign (pill, GTK_ALIGN_CENTER);
  gtk_widget_set_valign (pill, GTK_ALIGN_CENTER);
  gtk_container_add (GTK_CONTAINER (box), pill);
  gtk_container_add (GTK_CONTAINER (evbox), box);
  gtk_container_add (GTK_CONTAINER (self->bar_surface), evbox);
  gtk_widget_show_all (evbox);

  self->bar_drag = gtk_gesture_drag_new (evbox);
  g_signal_connect_object (self->bar_drag, "drag-end", G_CALLBACK (on_swivel_bar_drag_end),
                           self, G_CONNECT_SWAPPED);
  g_signal_connect_object (self->bar_surface, "destroy",
                           G_CALLBACK (on_bar_surface_destroy), self,
                           G_CONNECT_SWAPPED);
  gtk_widget_set_visible (self->bar_surface, gtk_widget_get_visible (GTK_WIDGET (self)));
}


static void
destroy_grid_surface (PhoshHome *self)
{'''),
(
'''                           G_CALLBACK (on_grid_surface_destroy), self,
                           G_CONNECT_SWAPPED);
}''',
'''                           G_CALLBACK (on_grid_surface_destroy), self,
                           G_CONNECT_SWAPPED);

  create_bar_surface (self, monitor);
}'''),
(
'''  destroy_grid_surface (self);

  g_clear_object (&self->settings);''',
'''  destroy_grid_surface (self);
  /* The home goes away (e.g. the primary monitor changed) but the monitor
   * signals stay connected until finalize, and the overview with the app
   * grid's place is gone: no more placement updates */
  self->grid_home = NULL;

  g_clear_object (&self->settings);'''),
(
'''static void
on_monitor_added (PhoshHome *self, PhoshMonitor *monitor)''',
'''/* Mapping a layer surface does a Wayland roundtrip: monitors can come and go
 * in the middle of a placement update, and their handlers would update again
 * inside it. Run nested requests after the current one instead. */
static void
update_app_grid_placement (PhoshHome *self)
{
  if (self->in_placement) {
    self->placement_again = TRUE;
    return;
  }

  self->in_placement = TRUE;
  do {
    self->placement_again = FALSE;
    update_app_grid_placement_once (self);
  } while (self->placement_again && self->grid_home);
  self->in_placement = FALSE;
}


static void
on_monitor_added (PhoshHome *self, PhoshMonitor *monitor)'''),
(
'''  gtk_widget_set_visible (self->grid_surface, show);
''',
'''  gtk_widget_set_visible (self->grid_surface, show);
  if (self->bar_surface)
    gtk_widget_set_visible (self->bar_surface, gtk_widget_get_visible (GTK_WIDGET (self)));
'''),
])
