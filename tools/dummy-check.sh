#!/bin/sh
# PulseAudio sinks/profiles in normal and in call mode
CPID=$(pgrep -u $(id -u) -x callaudiod | head -1)
export $(tr '\0' '\n' < /proc/$CPID/environ | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=')
CA="gdbus call --session --dest org.mobian_project.CallAudio --object-path /org/mobian_project/CallAudio --method org.mobian_project.CallAudio.SelectMode"
show() {
	echo "== $1"
	pactl list cards | grep -E 'Active Profile|^\s+(HiFi|Voice).*:' | sed 's/^\s*//' | cut -c1-110
	pactl list short sinks | cut -c1-110
	echo "default: $(pactl get-default-sink)"
}
show "normal"
$CA 1 >/dev/null; sleep 4
show "call mode"
$CA 0 >/dev/null; sleep 4
show "back to normal"
