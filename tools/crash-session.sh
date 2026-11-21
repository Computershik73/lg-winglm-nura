#!/bin/sh
# Install phosh r22, start a one-shot autologin session whose output goes to /tmp/sess.log, reproduce the swivel crash
R=/home/user/.local/share/abuild/aports
args=""; for p in $(apk info 2>/dev/null | grep -E '^(phosh|libphosh)' | sort -u); do [ -f $R/aarch64/$p-0.58.0-r22.apk ] && args="$args $p=0.58.0-r22"; done
sudo apk add --no-network --repository $R $args 2>&1 | tail -1
C=/etc/phrog/greetd-config.toml
sudo cp $C /var/lib/winglm-greetd-config.toml.before-autologin
printf '#!/bin/sh\nexec /usr/bin/phosh-session > /tmp/sess.log 2>&1\n' | sudo tee /usr/local/bin/winglm-logged-session >/dev/null
sudo chmod 755 /usr/local/bin/winglm-logged-session
printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/local/bin/winglm-logged-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
sudo rm -f /run/greetd.run
sudo rc-service greetd restart >/dev/null 2>&1
for i in $(seq 1 30); do pgrep -u user -x phosh >/dev/null && break; sleep 1; done
sudo cp /var/lib/winglm-greetd-config.toml.before-autologin $C; sudo rm -f /var/lib/winglm-greetd-config.toml.before-autologin
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C), phosh: $(pgrep -u user -x phosh)"
sleep 12
echo "alive after start: $(pgrep -u user -x phosh)"
INJ=/sys/devices/platform/soc/soc:gpio_keys/swivel_event_injector
echo 1 | sudo tee $INJ >/dev/null; sleep 4; echo 2 | sudo tee $INJ >/dev/null; sleep 6
echo "alive after swivel: $(pgrep -u user -x phosh)"
grep -iE "error|protocol|wl_|zwlr|crit|phosh-home|exit" /tmp/sess.log | grep -vE "GL_|EGL_" | tail -15 | cut -c1-240
