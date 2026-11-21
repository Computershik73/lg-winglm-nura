#!/bin/sh
# One-shot session again, phosh alone with WAYLAND_DEBUG=client, reproduce, show the tail of its protocol log
mkdir -p /home/user/.local/share/applications
sed 's#^Exec=.*#Exec=/bin/sh -c "WAYLAND_DEBUG=client exec /usr/libexec/phosh 2>/tmp/phosh-wl.log"#' /usr/share/applications/mobi.phosh.Shell.desktop > /home/user/.local/share/applications/mobi.phosh.Shell.desktop
grep '^Exec' /home/user/.local/share/applications/mobi.phosh.Shell.desktop
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
sudo rm -f /run/greetd.run
sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 30); do pgrep -u user -x phosh >/dev/null && break; sleep 1; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C), phosh: $(pgrep -u user -x phosh)"
sleep 12
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
N0=$(wc -l < /tmp/phosh-wl.log)
echo 1 | sudo tee $INJ >/dev/null; sleep 4
N1=$(wc -l < /tmp/phosh-wl.log)
echo 2 | sudo tee $INJ >/dev/null; sleep 6
echo "alive after swivel: $(pgrep -u user -x phosh); log lines $N0 $N1 $(wc -l < /tmp/phosh-wl.log)"
rm -f /home/user/.local/share/applications/mobi.phosh.Shell.desktop
cp /tmp/phosh-wl.log /tmp/phosh-wl-keep.log
