#!/bin/sh
id user
python3 - <<'EOF'
try:
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Gtk, Adw, Gio
    print("gi ok: gtk", Gtk.get_major_version(), Gtk.get_minor_version(), "adw", Adw.get_major_version(), Adw.get_minor_version())
except Exception as e:
    print("gi missing:", e)
EOF
apk info -e py3-gobject3 >/dev/null && echo "py3-gobject3 installed" || echo "py3-gobject3 not installed"
