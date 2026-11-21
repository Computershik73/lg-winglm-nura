#!/bin/sh
# Install stevia r10 + device-lg-winglm r14 and restart stevia and winglm-swivel inside the user session
R=/home/user/.local/share/abuild/aports
pkgs=""
for p in $(apk info 2>/dev/null | grep -xE 'stevia(-lang|-schemas|-dbg|-doc|-systemd)?'); do
	pkgs="$pkgs $p=0.58.0-r10"
done
sudo apk add --no-network --repository "$R" $pkgs 2>&1 | grep -E 'Upgrading|ERROR|OK:' | tail -5
sudo apk add --allow-untrusted --no-network /tmp/device-lg-winglm-1-r14.apk /tmp/device-lg-winglm-phosh-1-r14.apk 2>&1 | grep -E 'Upgrading|ERROR|OK:' | tail -3
gsettings list-keys mobi.phosh.osk | grep -x output && echo "schema has output key"
gsettings list-keys org.postmarketos.winglm.swivel | grep -x osk-on-swivel
# session environment of the logged-in phosh session
PP=$(pgrep -u user -x phosh | head -1)
[ -n "$PP" ] || { echo "no phosh session"; exit 1; }
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|XDG_SESSION_ID|XDG_SEAT|HOME|USER|PATH|XDG_CURRENT_DESKTOP|XDG_DATA_DIRS)=' > /tmp/phosh-user.env
cat /tmp/phosh-user.env | cut -d= -f1 | tr '\n' ' '; echo
# stevia: gnome-session restarts it (X-GNOME-AutoRestart)
OLD=$(pgrep -u user -x phosh-osk-stevi | head -1)
[ -n "$OLD" ] || OLD=$(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1)
echo "stevia was $OLD"
[ -n "$OLD" ] && kill "$OLD"
sleep 4
echo "stevia now $(pgrep -u user -f '^/usr/bin/phosh-osk-stevia' | head -1)"
