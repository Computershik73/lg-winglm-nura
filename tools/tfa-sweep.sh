#!/bin/sh
# speaker -> microphone loudness per TFA9878 gain setting (quiet 440 Hz tone)
# usage: tfa-sweep.sh FIELD VALUES...   FIELD: spkg (TDMSPKG) or ampgain
E="env -i $(cat /tmp/phosh-user.env | tr '\n' ' ')"
F=$1; shift
case $F in
	spkg) R=0x5f P=6 L=4 DEF=4 ;;
	ampgain) R=0x52 P=5 L=8 DEF=195 ;;
esac
python3 /tmp/tone.py /tmp/tone2.wav 2.0 ${DBFS:--18}
$E pactl get-sink-volume @DEFAULT_SINK@ | head -1
SRC=$($E pactl get-default-source)
echo "source $SRC"
# keep the amplifier running between the steps
python3 /tmp/tone.py /tmp/silence.wav 30 -200
$E paplay /tmp/silence.wav &
KEEP=$!
sleep 1
for v in "$@"; do
	sudo python3 /tmp/tfa-set.py $R $P $L $v >/dev/null
	# record 1.6 s, the tone starts 0.1 s in; analyse the last second
	($E parec --raw --format=s16le --rate=48000 --channels=1 --latency-msec=50 -d "$SRC" 2>/dev/null | head -c 153600 > /tmp/rec.raw) &
	REC=$!
	sleep 0.1
	$E paplay /tmp/tone2.wav &
	PL=$!
	wait $REC
	kill $PL 2>/dev/null; wait $PL 2>/dev/null
	python3 - "$v" <<'PY'
import math, struct, sys
d = open('/tmp/rec.raw', 'rb').read()
n = len(d) // 2
s = struct.unpack('<%dh' % n, d[:2 * n])[-48000:] if n else ()
n = len(s)
rms = math.sqrt(sum(x * x for x in s) / n) if n else 0
# 440 Hz component (Goertzel)
k = 2 * math.cos(2 * math.pi * 440 / 48000)
s1 = s2 = 0.0
for x in s:
    s1, s2 = x + k * s1 - s2, s1
p = math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) * 2 / n if n else 0
db = lambda v: 20 * math.log10(v / 32768) if v > 0 else -200
print('%s=%-4s 440 Hz %6.1f dBFS   broadband %6.1f dBFS' % ('value', sys.argv[1], db(p), db(rms)))
PY
done
sudo python3 /tmp/tfa-set.py $R $P $L $DEF
kill $KEEP 2>/dev/null
