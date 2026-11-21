import sys, os

top = sys.argv[1]  # stevia source dir (contains data/ and src/)


def edit(name, pairs):
    p = os.path.join(top, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r" % (name, old[:70])
        s = s.replace(old, new)
    open(p, "w").write(s)


# ------------------------------------------------------------------ schema
edit("data/mobi.phosh.osk.gschema.xml", [(
'''    <key name="schema-migration" type='u'>''',
'''    <key name="output" type='s'>
      <default>''</default>
      <summary>Output to show the keyboard on</summary>
      <description>
        Connector name of the output (e.g. DSI-2) the keyboard should be
        shown on. If empty or no such output exists the compositor picks
        one.
      </description>
    </key>

    <key name="schema-migration" type='u'>''')])

# ------------------------------------------------------------------ PosOutput
edit("src/pos-output.h", [(
'''gboolean           pos_output_is_portrait (PosOutput *self);''',
'''gboolean           pos_output_is_portrait (PosOutput *self);
const char *       pos_output_get_name (PosOutput *self);
struct wl_output * pos_output_get_wl_output (PosOutput *self);''')])

edit("src/pos-output.c", [(
'''guint
pos_output_get_logical_height (PosOutput *self)''',
'''const char *
pos_output_get_name (PosOutput *self)
{
  g_assert (POS_IS_OUTPUT (self));

  return self->current.name;
}


struct wl_output *
pos_output_get_wl_output (PosOutput *self)
{
  g_assert (POS_IS_OUTPUT (self));

  return self->wl_output;
}


guint
pos_output_get_logical_height (PosOutput *self)''')])

# ------------------------------------------------------------------ size manager
edit("src/pos-size-manager.h", [(
'''#include <glib-object.h>
''',
'''#include "pos-output.h"

#include <glib-object.h>
'''), (
'''PosSizeManager *pos_size_manager_new (void);''',
'''PosSizeManager *pos_size_manager_new (void);
void            pos_size_manager_set_preferred_output (PosSizeManager *self,
                                                       PosOutput      *output);''')])

edit("src/pos-size-manager.c", [
(
'''  PosOutput *output;
  guint      height;''',
'''  PosOutput *output;
  PosOutput *preferred; /* weak: the output the app put the keyboard on */
  guint      height;'''),
(
'''  if (self->output)
    g_signal_handlers_disconnect_by_data (self->output, self);''',
'''  if (self->output)
    g_signal_handlers_disconnect_by_func (self->output, on_output_configured, self);'''),
(
'''  if (pos_wayland_get_n_outputs (wayland) != 1) {''',
'''  /* Size for the output the keyboard was explicitly put on */
  if (self->preferred) {
    set_output (self, self->preferred);
    on_output_configured (self, self->output);
    return;
  }

  if (pos_wayland_get_n_outputs (wayland) != 1) {'''),
(
'''  g_clear_object (&self->settings);''',
'''  g_clear_weak_pointer (&self->preferred);
  g_clear_object (&self->settings);'''),
(
'''PosSizeManager *
pos_size_manager_new (void)''',
'''/**
 * pos_size_manager_set_preferred_output:
 * @self: The size manager
 * @output: (nullable): The output the keyboard is shown on
 *
 * Size the keyboard for @output. With %NULL the size manager picks an
 * output itself (if there's only one).
 */
void
pos_size_manager_set_preferred_output (PosSizeManager *self, PosOutput *output)
{
  g_assert (POS_IS_SIZE_MANAGER (self));

  if (self->preferred == output)
    return;

  g_set_weak_pointer (&self->preferred, output);
  on_outputs_changed (self, NULL, pos_wayland_get_default ());
}


PosSizeManager *
pos_size_manager_new (void)'''),
])

# ------------------------------------------------------------------ app
edit("src/phosh-osk-stevia.c", [
(
'''  PosSizeManager      *size_manager;
  int exit_status;''',
'''  PosSizeManager      *size_manager;
  GSettings           *osk_settings;
  PosOutput           *surface_output; /* weak: output the input surface was put on */
  int                  surface_busy;    /* creating / recreating the input surface */
  gboolean             surface_recheck; /* output changes seen meanwhile */
  gboolean             create_pending;  /* waiting for the outputs' names */
  PosInputMethod      *surface_im;      /* weak: the input surface's input method */
  gboolean             im_wait;         /* waiting for the old input method to go */
  int exit_status;'''),
# pick the output when creating the surface
(
'''  force_completion = !!(_debug_flags & POS_DEBUG_FLAG_FORCE_COMPLETEION);
  self->input_surface = g_object_new (POS_TYPE_INPUT_SURFACE,''',
'''  self->surface_busy++;
  output = find_wanted_output (self);
  g_set_weak_pointer (&self->surface_output, output);
  g_set_weak_pointer (&self->surface_im, im);
  pos_size_manager_set_preferred_output (self->size_manager, output);
  g_debug ("Creating input surface on %s",
           output ? pos_output_get_name (output) : "the compositor's choice of output");

  force_completion = !!(_debug_flags & POS_DEBUG_FLAG_FORCE_COMPLETEION);
  self->input_surface = g_object_new (POS_TYPE_INPUT_SURFACE,
                                      "wl-output", output ? pos_output_get_wl_output (output) : NULL,'''),
(
'''  PosWayland *wayland = pos_wayland_get_default ();
  gboolean force_completion;
''',
'''  PosWayland *wayland = pos_wayland_get_default ();
  gboolean force_completion;
  PosOutput *output;
'''),
# helpers before create_input_surface
(
'''static void
create_input_surface (PosApp *self)
{''',
'''/* The output named in the 'output' setting, if it's there */
static PosOutput *
find_wanted_output (PosApp *self)
{
  g_autofree char *name = NULL;
  GPtrArray *outputs;

  if (!self->osk_settings)
    return NULL;

  name = g_settings_get_string (self->osk_settings, "output");
  if (!name || !*name)
    return NULL;

  outputs = pos_wayland_get_outputs (pos_wayland_get_default ());
  for (guint i = 0; i < outputs->len; i++) {
    PosOutput *output = g_ptr_array_index (outputs, i);

    if (g_strcmp0 (pos_output_get_name (output), name) == 0)
      return output;
  }

  return NULL;
}


static void maybe_create_input_surface (PosApp *self);

static void
on_deferred_create (gpointer data)
{
  maybe_create_input_surface (POS_APP (data));
}


static void
on_old_im_gone (gpointer data, GObject *where_the_object_was)
{
  PosApp *self = POS_APP (data);

  self->im_wait = FALSE;
  /* Leave the finalize first */
  g_idle_add_once (on_deferred_create, self);
}


/* An output is wanted but the outputs don't have their names yet */
static gboolean
outputs_pending (PosApp *self)
{
  g_autofree char *name = NULL;
  GPtrArray *outputs;

  if (!self->osk_settings)
    return FALSE;

  name = g_settings_get_string (self->osk_settings, "output");
  if (!name || !*name)
    return FALSE;

  outputs = pos_wayland_get_outputs (pos_wayland_get_default ());
  if (outputs->len == 0)
    return TRUE;

  for (guint i = 0; i < outputs->len; i++) {
    if (!pos_output_get_name (g_ptr_array_index (outputs, i)))
      return TRUE;
  }

  return FALSE;
}

/* Recreate the input surface if it's not on the wanted output */
static void
check_input_surface_output (PosApp *self)
{
  PosOutput *wanted = find_wanted_output (self);

  /* Creating, mapping and destroying layer surfaces dispatches Wayland
   * events (output 'configured' among them): check again once done */
  if (self->surface_busy) {
    self->surface_recheck = TRUE;
    return;
  }

  if (!self->input_surface) {
    if (self->create_pending && !outputs_pending (self)) {
      self->create_pending = FALSE;
      maybe_create_input_surface (self);
    }
    return;
  }

  if (wanted == self->surface_output)
    return;

  g_debug ("Moving input surface to %s",
           wanted ? pos_output_get_name (wanted) : "the compositor's choice of output");
  self->surface_busy++;
  dispose_input_surface (self);
  self->input_surface = NULL;
  maybe_create_input_surface (self);
  self->surface_busy--;

  if (!self->surface_busy && self->surface_recheck) {
    self->surface_recheck = FALSE;
    check_input_surface_output (self);
  }
}


static void
on_outputs_changed (PosApp *self, GParamSpec *pspec, PosWayland *wayland)
{
  GPtrArray *outputs = pos_wayland_get_outputs (wayland);

  /* Output names arrive with the first 'done' */
  for (guint i = 0; i < outputs->len; i++) {
    PosOutput *output = g_ptr_array_index (outputs, i);

    if (g_object_get_data (G_OBJECT (output), "pos-app-watched"))
      continue;

    g_object_set_data (G_OBJECT (output), "pos-app-watched", GINT_TO_POINTER (TRUE));
    g_signal_connect_object (output, "configured",
                             G_CALLBACK (check_input_surface_output), self,
                             G_CONNECT_SWAPPED);
  }

  check_input_surface_output (self);
}


static void
create_input_surface (PosApp *self)
{'''),
(
'''  g_object_weak_ref (G_OBJECT (self->input_surface), on_input_surface_gone, self);
}''',
'''  g_object_weak_ref (G_OBJECT (self->input_surface), on_input_surface_gone, self);

  self->surface_busy--;
  if (!self->surface_busy && self->surface_recheck) {
    self->surface_recheck = FALSE;
    check_input_surface_output (self);
  }
}'''),
(
'''  g_debug ("Creating new input surface");
  create_input_surface (self);''',
'''  /* Don't create it on the wrong output only to move it right away */
  if (outputs_pending (self)) {
    g_debug ("Outputs not known yet, postponing input surface creation");
    self->create_pending = TRUE;
    return;
  }

  /* The old input surface (and with it its input method) is only finalized
   * later and the compositor hands out one input method per seat */
  if (self->surface_im) {
    if (!self->im_wait) {
      g_debug ("Waiting for the old input method to go");
      self->im_wait = TRUE;
      g_object_weak_ref (G_OBJECT (self->surface_im), on_old_im_gone, self);
    }
    return;
  }

  g_debug ("Creating new input surface");
  create_input_surface (self);'''),
# upstream bug: the dangling pointer kept maybe_create_input_surface() from recreating
(
'''  g_debug ("Input surface gone, recreating");
  maybe_create_input_surface (self);''',
'''  g_debug ("Input surface gone, recreating");
  /* The compositor closed it (e.g. its output went away): forget it so a
   * new one gets created */
  self->input_surface = NULL;
  maybe_create_input_surface (self);'''),
# settings + signals
(
'''  self->session_proxy = pos_app_session_register (self, APP_ID);
  self->size_manager = pos_size_manager_new ();
''',
'''  self->session_proxy = pos_app_session_register (self, APP_ID);
  self->size_manager = pos_size_manager_new ();

  self->osk_settings = g_settings_new ("mobi.phosh.osk");
  g_signal_connect_object (self->osk_settings, "changed::output",
                           G_CALLBACK (check_input_surface_output), self,
                           G_CONNECT_SWAPPED);
  g_signal_connect_object (wayland, "notify::outputs",
                           G_CALLBACK (on_outputs_changed), self,
                           G_CONNECT_SWAPPED);
  on_outputs_changed (self, NULL, wayland);
'''),
(
'''  g_clear_object (&self->emoji_db);
  g_clear_object (&self->size_manager);''',
'''  g_clear_object (&self->emoji_db);
  g_clear_object (&self->size_manager);
  g_clear_weak_pointer (&self->surface_output);
  if (self->surface_im && self->im_wait)
    g_object_weak_unref (G_OBJECT (self->surface_im), on_old_im_gone, self);
  g_clear_weak_pointer (&self->surface_im);
  g_clear_object (&self->osk_settings);'''),
])
edit("src/pos-input-surface.c", [
('''  /* Backspace handling */
  guint                       bs_repeat_id;''',
'''  /* Backspace handling */
  guint                       bs_repeat_id;
  guint                       delayed_init_id;'''),
('''static void
delayed_init (PosInputSurface *self)
{
  pos_vk_driver_key_press_gdk (self->keyboard_driver, GDK_KEY_BackSpace, 0);
}''',
'''static gboolean input_serial_sent;

static void
delayed_init (PosInputSurface *self)
{
  self->delayed_init_id = 0;
  pos_vk_driver_key_press_gdk (self->keyboard_driver, GDK_KEY_BackSpace, 0);
}'''),
('''  static gboolean input_serial_sent = FALSE;
  PosInputSurface *self = POS_INPUT_SURFACE (object);''',
'''  PosInputSurface *self = POS_INPUT_SURFACE (object);'''),
('''    g_timeout_add_seconds_once (1, (GSourceOnceFunc)delayed_init, self);
    input_serial_sent = TRUE;''',
'''    self->delayed_init_id = g_timeout_add_seconds_once (1, (GSourceOnceFunc)delayed_init, self);
    input_serial_sent = TRUE;'''),
('''  g_clear_handle_id (&self->animation.id, g_source_remove);
  g_clear_handle_id (&self->bs_repeat_id, g_source_remove);''',
'''  g_clear_handle_id (&self->animation.id, g_source_remove);
  g_clear_handle_id (&self->bs_repeat_id, g_source_remove);
  /* Gone before the workaround's key press (e.g. moved to another output
   * right away): don't press with a freed driver, let the next one do it */
  if (self->delayed_init_id) {
    g_clear_handle_id (&self->delayed_init_id, g_source_remove);
    input_serial_sent = FALSE;
  }'''),
])
print("patched stevia")
