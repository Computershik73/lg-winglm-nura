#!/bin/sh
# One-shot autologin (config restored right after greetd starts it), then PipeWire checks in the session
C=/etc/phrog/greetd-config.toml
if ! pgrep -u user -x phosh >/dev/null; then
	sudo cp $C /tmp/greetd-config.toml.before-autologin
	printf '\n# TEMPORARY one-shot autologin for on-device tests (removed right after start)\n[initial_session]\ncommand = "/usr/bin/phosh-session"\nuser = "user"\n' | sudo tee -a $C >/dev/null
	sudo rm -f /run/greetd.run
	sudo rc-service greetd restart >/dev/null 2>&1
	sleep 25
	sudo cp /tmp/greetd-config.toml.before-autologin $C
fi
echo "autologin lines left: $(grep -c '^\[initial_session\]' $C)"
PP=$(pgrep -u user -x phosh | head -1)
[ -n "$PP" ] || { echo "no session"; exit 1; }
tr '\0' '\n' < /proc/$PP/environ | grep -E '^(XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|HOME|USER|PATH|XDG_CURRENT_DESKTOP)=' > /tmp/phosh-user.env
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
sleep 5
$E wpctl status 2>&1 | sed -n '/Audio/,/Video/p' | head -30
# play through the default sink, record from the default source
$E pw-record --rate 48000 --channels 1 --format s16 /tmp/pw-mic.wav > /dev/null 2>&1 &
R=$!
sleep 0.8
$E pw-play /tmp/tone.wav > /dev/null 2>&1
sleep 1; kill $R; sleep 0.5
python3 - <<'EOF'
import math, struct, wave
w = wave.open("/tmp/pw-mic.wav"); n = w.getnframes(); data = w.readframes(n); w.close()
s = struct.unpack("<%dh" % (len(data) // 2), data)
def goertzel(x, f, rate=48000):
    k = 2 * math.cos(2 * math.pi * f / rate); s1 = s2 = 0.0
    for v in x: s0 = v + k * s1 - s2; s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) / max(len(x), 1)
rms = lambda x: math.sqrt(sum(v * v for v in x) / max(len(x), 1))
print("recorded %.1f s" % (len(s) / 48000))
for name, (a, b) in (("before", (0.0, 0.6)), ("during", (1.2, 3.0))):
    x = s[int(a * 48000):int(b * 48000)]
    print("%-6s rms %7.1f  1kHz %8.2f" % (name, rms(x), goertzel(x, 1000)))
EOF
