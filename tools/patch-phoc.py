import sys, os
p = os.path.join(sys.argv[1], "src", "seat.c")
s = open(p).read()
old = '''  touch = wlr_touch_from_input_device (wlr_device);

  if (!touch->output_name)
    return NULL;

  g_debug ("Looking up output %s", touch->output_name);
  return phoc_desktop_find_output_by_name (desktop, touch->output_name);'''
new = '''  touch = wlr_touch_from_input_device (wlr_device);
  output_name = touch->output_name;

  /* wlroots does not fill in output_name for libinput devices: ask libinput,
   * which reads the WL_OUTPUT udev property. Devices with two touchscreens
   * (LG Wing) need this to map each one to its own panel. */
  if (!output_name && phoc_input_device_get_is_libinput (device)) {
    struct libinput_device *ldev = phoc_input_device_get_libinput_device_handle (device);

    if (ldev)
      output_name = libinput_device_get_output_name (ldev);
  }

  if (!output_name)
    return NULL;

  g_debug ("Looking up output %s", output_name);
  return phoc_desktop_find_output_by_name (desktop, output_name);'''
assert s.count(old) == 1, "body"
s = s.replace(old, new)
old2 = '''  struct wlr_input_device *wlr_device = phoc_input_device_get_device (device);
  struct wlr_touch *touch;

  if (wlr_device->type != WLR_INPUT_DEVICE_TOUCH)'''
new2 = '''  struct wlr_input_device *wlr_device = phoc_input_device_get_device (device);
  struct wlr_touch *touch;
  const char *output_name;

  if (wlr_device->type != WLR_INPUT_DEVICE_TOUCH)'''
assert s.count(old2) == 1, "decl"
s = s.replace(old2, new2)
open(p, "w").write(s)
print("patched")
