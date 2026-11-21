#!/bin/sh
CPID=$(pgrep -u $(id -u) -x callaudiod | head -1)
export $(tr '\0' '\n' < /proc/$CPID/environ | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=')
echo "== who holds the PCMs"
for d in /dev/snd/pcmC0D*; do
	u=$(sudo fuser $d 2>/dev/null)
	[ -n "$u" ] && for p in $u; do echo "$d: $p $(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-80)"; done
done
echo "== PA modules (alsa)"
pactl list short modules | grep -iE 'alsa|udev|null' | cut -c1-150
echo "== PA log (syslog)"
sudo logread 2>/dev/null | grep -aiE 'pulseaudio' | tail -25 | cut -c1-220
echo "== uptime / PA start"
uptime; ps -o pid,etime,args | grep -E '[p]ulseaudio' | cut -c1-80
