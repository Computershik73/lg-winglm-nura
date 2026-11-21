import sys, os

top = sys.argv[1]  # phoc source dir
which = sys.argv[2]  # "osk" or "move"


def edit(name, pairs):
    p = os.path.join(top, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r" % (name, old[:70])
        s = s.replace(old, new)
    open(p, "w").write(s)


if which == "osk":
    edit("src/input-method-relay.c", [(
'''static void
elevate_osk (struct wlr_surface *surface)
{
  struct wlr_layer_surface_v1 *layer;

  if (!surface)
    return;

  layer = wlr_layer_surface_v1_try_from_wlr_surface (surface);
  if (!layer)
    return;

  phoc_layer_shell_update_osk (PHOC_OUTPUT (layer->output->data), TRUE);
}''',
'''static void
elevate_osk (struct wlr_surface *surface)
{
  PhocDesktop *desktop = phoc_server_get_desktop (phoc_server_get_default ());
  struct wlr_layer_surface_v1 *layer;
  PhocOutput *output;

  if (!surface)
    return;

  layer = wlr_layer_surface_v1_try_from_wlr_surface (surface);
  if (!layer)
    return;

  /* The OSK can be on another output than the layer surface that wants
   * input (e.g. a lock screen on the main screen and the OSK on a second
   * built-in one) */
  wl_list_for_each (output, &desktop->outputs, link)
    phoc_layer_shell_update_osk (output, TRUE);
}''')])
    print("patched osk")
    sys.exit(0)

# ---------------------------------------------------------------- move toplevel
REQ = '''
    <request name="move_toplevel_to_output" since="9">
      <description summary="move a toplevel to another output">
        Moves the toplevel to the given output. When output is null the
        toplevel moves to the next enabled output.
      </description>
      <arg name="toplevel" type="object" interface="zwlr_foreign_toplevel_handle_v1"/>
      <arg name="output" type="object" interface="wl_output" allow-null="true"/>
    </request>
'''
edit("protocols/phosh-private.xml", [
('''  <interface name="phosh_private" version="8">''',
 '''  <interface name="phosh_private" version="9">'''),
('''      <arg name="toplevel" type="object" interface="zwlr_foreign_toplevel_handle_v1"/>
      <arg name="layer_surface" type="object" interface="zwlr_layer_surface_v1"/>
    </request>
''',
'''      <arg name="toplevel" type="object" interface="zwlr_foreign_toplevel_handle_v1"/>
      <arg name="layer_surface" type="object" interface="zwlr_layer_surface_v1"/>
    </request>
''' + REQ),
])

edit("src/view.h", [(
'''bool                  phoc_view_move_to_next_output (PhocView *self, enum wlr_direction direction);''',
'''bool                  phoc_view_move_to_next_output (PhocView *self, enum wlr_direction direction);
bool                  phoc_view_move_to_output (PhocView *self, PhocOutput *output);''')])

edit("src/view.c", [(
'''bool
phoc_view_move_to_next_output (PhocView *self, enum wlr_direction direction)
{''',
'''/**
 * phoc_view_move_to_output:
 * @self: The view
 * @output: The output to move the view to
 *
 * Move the view to the center of `output`'s usable area keeping its
 * maximized / fullscreen state.
 *
 * Returns: %TRUE if the view was moved
 */
bool
phoc_view_move_to_output (PhocView *self, PhocOutput *output)
{
  PhocDesktop *desktop = phoc_server_get_desktop (phoc_server_get_default ());
  const struct wlr_output_layout_output *l_output;
  struct wlr_box usable_area;
  double x, y;

  g_assert (PHOC_IS_VIEW (self));
  g_assert (PHOC_IS_OUTPUT (output));

  l_output = wlr_output_layout_get (desktop->layout, output->wlr_output);
  if (!l_output)
    return false;

  usable_area = output->usable_area;
  x = usable_area.x + l_output->x + usable_area.width / 2 - self->saved.width / 2;
  y = usable_area.y + l_output->y + usable_area.height / 2 - self->saved.height / 2;
  g_debug ("moving view's saved position to %f %f on %s", x, y, output->wlr_output->name);
  self->saved.x = x;
  self->saved.y = y;

  if (phoc_view_is_fullscreen (self)) {
    phoc_view_set_fullscreen (self, true, output);
    return true;
  }

  phoc_view_arrange (self, output, TRUE);
  return true;
}


bool
phoc_view_move_to_next_output (PhocView *self, enum wlr_direction direction)
{''')])

edit("src/phosh-private.c", [
('''#define PHOSH_PRIVATE_VERSION 8''', '''#define PHOSH_PRIVATE_VERSION 9'''),
('''static void
handle_set_shell_state (struct wl_client               *client,''',
'''static void
handle_move_toplevel_to_output (struct wl_client   *client,
                                struct wl_resource *phosh_private_resource,
                                struct wl_resource *toplevel_resource,
                                struct wl_resource *output_resource)
{
  PhocDesktop *desktop = phoc_server_get_desktop (phoc_server_get_default ());
  struct wlr_foreign_toplevel_handle_v1 *toplevel_handle;
  PhocOutput *output = NULL, *current, *iter, *first = NULL;
  gboolean take_next = FALSE;
  PhocView *view;

  toplevel_handle = wl_resource_get_user_data (toplevel_resource);
  if (!toplevel_handle || !toplevel_handle->data)
    return;
  view = toplevel_handle->data;

  if (output_resource) {
    struct wlr_output *wlr_output = wlr_output_from_resource (output_resource);

    if (!wlr_output || !wlr_output->data)
      return;
    output = PHOC_OUTPUT (wlr_output->data);
  } else {
    /* The next enabled output after the view's current one */
    current = phoc_view_get_output (view);
    wl_list_for_each (iter, &desktop->outputs, link) {
      if (!iter->wlr_output->enabled ||
          !wlr_output_layout_get (desktop->layout, iter->wlr_output))
        continue;
      if (!first)
        first = iter;
      if (take_next) {
        output = iter;
        break;
      }
      if (iter == current)
        take_next = TRUE;
    }
    if (!output)
      output = first;
    if (!output || output == current)
      return;
  }

  g_debug ("Moving view %p to %s", view, output->wlr_output->name);
  phoc_view_move_to_output (view, output);
}


static void
handle_set_shell_state (struct wl_client               *client,'''),
('''  handle_add_thumbnail_view,   /* interface */
};''',
'''  handle_add_thumbnail_view,   /* interface */
  handle_move_toplevel_to_output, /* request */
};'''),
])
print("patched move")
