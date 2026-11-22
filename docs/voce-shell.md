# Voce shell on the LG Wing (branch `voce-shell`)

The Voce shell (`wayland-mobile-shell`, repository VoceOS/voce-shell, branch
`pmos` + our branch `nura-winglm`) is the shell for the QWERTY phone the Wing
port is the development platform for. This branch packages it as a second
session next to Phosh. Phosh stays the default and the fallback; the Voce
session only uses the swivel screen (DSI-2, 1080x1240), the only screen the
QWERTY prototype will have. The main screen (DSI-1) is always off in it.

Target hardware: one display, the small one (the Wing's swivel panel,
1080x1240, about 360x413 logical at scale 3); where the Wing has its main
screen, the custom phone has a hardware QWERTY keyboard. So the shell is
designed for that one screen (its layout is drawn for 1080 units of width)
and a physical keyboard: no on-screen keyboard by default, keyboard focus,
navigation and shortcuts matter. How the keyboard connects to the SoC
(I2C/GPIO matrix/USB/Bluetooth) is not known yet. The Voce session needs no
kernel change for this; `device-lg-winglm-small-only` (DSI-1 off on the
kernel command line, for the greeter too) is the alternative, it needs a
boot image flash.

## What the shell is at runtime

* **Its own Wayland compositor**, not a client: `QtWaylandCompositor`
  (Qt 6, QML) with `xdg-shell`, `xdg-decoration` (server side) and
  `text-input` (`TextInputManager`). No `wlr-layer-shell`,
  `wlr-output-management`, `wlr-screencopy`, `input-method` or
  `linux-dmabuf` for clients. It lives in one process, `wayland-mobile-shell`;
  clients connect to the socket `$XDG_RUNTIME_DIR/wayland-wms`.
* **Output and input**: Qt's `eglfs` platform with the `eglfs_kms`
  integration draws straight to KMS (`/dev/dri/card0`, GBM + EGL) and reads
  input through libinput. No logind/libseat device handling: it opens the
  DRM node and the event nodes itself (the user is in the `video` and
  `input` groups) and becomes DRM master as the only client of card0.
* **GPU**: OpenGL ES 3.2 from the KGSL Mesa (`mesa-kgsl`): zink on turnip
  (Adreno 620). Qt's libraries have `RUNPATH=$ORIGIN`, which musl searches
  before `/etc/ld-musl-aarch64.path`, so the session sets
  `LD_LIBRARY_PATH=/usr/lib/mesa-kgsl`; otherwise Qt picks Alpine's Mesa.
* **Clients** are started by the shell (app grid) with software rendering
  (`QT_QUICK_BACKEND=software`, `LIBGL_ALWAYS_SOFTWARE=1`): Mesa 26 has no
  `EGL_WL_bind_wayland_display`, and QtWaylandCompositor's hardware buffer
  integrations (wl_drm and `linux-dmabuf-unstable-v1`) both still require it.
* **System services it talks to** (all asynchronously, since r10): UPower
  (battery), NetworkManager (`nmcli`: Wi-Fi, airplane mode, mobile data),
  BlueZ (Bluetooth), PulseAudio (`pactl`, volume; `wpctl` when there is no
  `pactl`), ModemManager (signal strength), logind (backlight and torch
  through `Session.SetBrightness` when sysfs is not writable; power off and
  restart), MPRIS players (music widget), GNOME Calls (`org.gnome.Calls`,
  call overlay; ModemManager when GNOME Calls is not running). It is the
  session's `org.freedesktop.Notifications` server.
* **Session services**: the shell starts XDG autostart entries like
  gnome-session does for Phosh (PulseAudio, `winglm-pulse-session`,
  `winglm-call-volume`, `winglm-volte-calls`, GNOME Calls, keyring, PipeWire,
  `mpris-proxy`, ...). `voce-shell-session` leaves out GNOME's settings
  daemons and the port's swivel and brightness daemons
  (`WMS_AUTOSTART_SKIP`).
* **Own apps** in the same package: `voce-dialer` (calls log, contacts,
  dial pad, messages; ModemManager over D-Bus) and `voce-organizer` (clock,
  calendar, calculator, files). Their `.desktop` files get
  `OnlyShowIn=Voce;`, so Phosh does not list them.

## The session

`aports/voce-shell` builds the package natively on the phone:

```sh
# on the PC (WSL): tarball of the pinned commit + aport to the phone, build
tools/voce-shell-dist.sh ~/src/voce-shell      # a checkout with the pinned commit
# on the phone
sudo apk add --allow-untrusted ~/.local/share/abuild/aports/aarch64/voce-shell-*.apk
```

The shell repository is private, so abuild cannot fetch the source;
`voce-shell-dist.sh` makes it with `git archive` (same bytes for the same
commit). After moving `_commit` to a new commit run
`tools/voce-shell-dist.sh <checkout> checksum` first.

phrog lists the session as **Voce** (`/usr/share/wayland-sessions/voce.desktop`,
`Exec=voce-shell-session`). `voce-shell-session`:

* starts a D-Bus session bus (`dbus-run-session`);
* writes a `QT_QPA_EGLFS_KMS_CONFIG` with only `DSI2` on and `DSI1`,
  `Virtual1` (the msm_drm writeback connector), `DP1` off, and maps the
  swivel panel's touch controller (`touch_sub_dev`) to it;
* sets `WMS_GL_FINISH=1` (KGSL has no implicit fences: glFinish before each
  page flip, like phoc's wlroots patch), `WMS_BACKLIGHT_DIR` =
  `panel1-backlight`, the KGSL Mesa;
* sets `WMS_UI_SCALE=2.5` (the shell sets `QT_SCALE_FACTOR` from it for itself
  only): the lock screen, home cards, app grid and window list are sized in
  pixels for a 720x720 window and were tiny on the ~420 ppi panel; the parts
  from the Figma mockup (status bar, shade, call screen) follow the width and
  keep their designed size (the status bar is drawn 1.5x the mockup, the
  shade has bigger labels, toggles and slider knobs), apps stay at native
  resolution;
* sets `WMS_CLIENT_SCALE=3`: apps see an output scale of 3 like under Phosh
  and get a maximized 360x413 logical window, so GTK/libadwaita apps use
  their mobile layouts; `XDG_CURRENT_DESKTOP=Voce:GNOME` (GNOME Settings
  refuses to start outside GNOME), exported before the session bus starts;
* `voce-portals.conf`: xdg-desktop-portal backends for the session (GTK).
  The shell hands the environment it starts apps with to D-Bus activation
  (`UpdateActivationEnvironment`, as gnome-session does for Phosh), so the
  portal and DBusActivatable apps reach its socket; GTK apps then get their
  settings from the portal (no window buttons with `button-layout=appmenu:`,
  dark style) like under Phosh;
* the shell implements Mutter's display API `org.gnome.Mutter.DisplayConfig`
  (as Phosh does): GNOME Settings shows the screen and changes the apps'
  scale (wl_output scale) and the orientation at runtime: the whole shell UI
  turns, touches follow, apps get the rotated size; what is applied there is
  kept in `~/.config/voce-shell/display.ini` (the scale wins over
  `WMS_CLIENT_SCALE`);
* logs to `~/.cache/voce-shell/session.log`; `~/.config/voce-shell/env` is
  sourced first for tests (`VOCE_OUTPUT`, `VOCE_SHELL`, `WMS_UI_SCALE`, Qt
  variables).

Behaviour in the session:

* the swivel is ignored (`winglm-swivel` is a Phosh-session service and
  elogind has `HandleLidSwitch=ignore`): closing it changes nothing;
* power key, short press: screen off (backlight 0) / on; touches on the
  blanked screen are ignored. Held for 0.8 s: menu with **Log out**, which
  ends the session and brings back the phrog greeter (Phosh, reboot,
  power off are there).

Remote tests: `ssh user@172.16.42.1 'sh -s voce' < tools/session-autologin.sh`
logs into Voce once without the greeter (`... 'sh -s phosh'` back to Phosh).
`kill -USR1 $(pidof wayland-mobile-shell)` saves a screenshot to `/tmp`.
`tools/touch-inject.py` taps/swipes on `touch_sub_dev` reach the shell.

## Status (first milestone)

| Area | State in the Voce session |
| --- | --- |
| Session from phrog next to Phosh, Phosh unchanged | ✅ |
| Swivel screen only, main screen off, GPU rendering (zink/turnip) | ✅ |
| Touch on the swivel screen | ✅ |
| Power key: blank/wake, hold → power menu | ✅ (backlight through logind); r10: Power off / Restart (logind) next to Log out |
| Brightness slider (shade) | ✅ panel1 through logind, asynchronous; the value is kept in `~/.config/voce-shell/shell.ini` and applied at start |
| Battery level (UPower) | ✅ |
| Lock screen | ⚠️ swipe only, no PIN |
| Apps from the grid | ⚠️ software rendering only (see GPU above); mobile layouts at scale 3, dialogs, closed windows leave the window list; touches mapped to the surface (QtWayland sends them unmapped, `VoceShellSurfaceItem` fixes it). r10: windows can no longer be dragged around, stay maximized, popups/dropdowns are kept on screen (flip/slide by the xdg_positioner rules); grid honours `OnlyShowIn`/`NotShowIn`/`TryExec`, reloads on install, design icons without an app open the organizer/dialer tab or a GNOME Software search |
| Volume slider, volume keys | r10: PulseAudio (`pactl`), level bar on the keys; PulseAudio now started by the session (autostart) |
| Calls | r10: GNOME Calls runs in the session (autostart) and handles CS and VoLTE as under Phosh; the shell's call overlay follows it over D-Bus. Not yet tested with a real call |
| GNOME Settings | ✅ mobile layout, dark style, no window buttons; Displays page: scale 100–400 % and orientation (0/90/180/270°) applied live and saved (the shell implements `org.gnome.Mutter.DisplayConfig` like Phosh); Night Light not supported |
| Notifications | ⚠️ the server runs; r10: lock screen entries can be opened/swiped away, the dots clear them all |
| On-screen keyboard | ❌ none (hardware QWERTY is the plan; no XKB layout set yet) |
| Bluetooth / airplane / mobile data toggles | r10: BlueZ `Adapter1.Powered`; airplane = `nmcli radio all` + BlueZ; mobile data = the gsm connection up/down (modem stays on for calls) |
| Flashlight | r10: `led:torch_0` + `led:switch_0` through logind |
| Status bar | r10: signal bars from ModemManager, Wi-Fi strength from NetworkManager |
| Widgets | r10: greeting with the user's name, music widget for any MPRIS player; no navigation service (the widget says so and opens maps) |
| Real screen off (DPMS) / suspend | ❌ blanking only sets the backlight to 0; suspend does not work on this kernel anyway |

## Plan

1. ~~Session services~~ (r10: XDG autostart in the shell).
2. **Calls**: r10 runs GNOME Calls and the shell's call overlay follows it.
   Left: `voce-dialer` still dials through ModemManager directly (no VoLTE)
   and has no SMS conversation view or sending.
3. **Shell fixes** (branch `nura-winglm`): drop or rotate
   `~/shell_debug.log` (grows forever); DPMS off through the eglfs screen
   power state instead of backlight 0.
4. **GPU for apps**: patch qt6-qtwayland so the compositor's
   `linux-dmabuf-unstable-v1` works without `EGL_WL_bind_wayland_display`
   (import dmabufs with `EGL_EXT_image_dma_buf_import`), then stop forcing
   software rendering in the app launcher.
5. **Keyboard**: XKB layouts (`us,ru`) and a layout switch for the hardware
   QWERTY; keyboard focus and navigation in the shell (app grid, shade, lock
   screen, call overlay) and shortcuts; on-screen keyboard only as an option
   (`text-input`/`input-method`). Ask the user how the keyboard connects
   once the shell work needs it.
6. **Lock screen PIN** (PAM).
