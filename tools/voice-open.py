#!/usr/bin/env python3
"""Open hw:0,DEV (VoiceMMode1) playback + capture like q6voiced: set_params 8 kHz mono S16, prepare; hold N s."""
import ctypes, sys, time
lib = ctypes.CDLL("libasound.so.2")
dev = sys.argv[1] if len(sys.argv) > 1 else "hw:0,2"
hold = float(sys.argv[2]) if len(sys.argv) > 2 else 5
pcms = []
for stream, name in ((0, "playback"), (1, "capture")):
    p = ctypes.c_void_p()
    r = lib.snd_pcm_open(ctypes.byref(p), dev.encode(), stream, 0)
    if r < 0:
        print("%s open: %s" % (name, ctypes.c_char_p(lib.snd_strerror(r)).value)); sys.exit(1)
    r = lib.snd_pcm_set_params(p, 2, 3, 1, 8000, 0, 500000)   # S16_LE, RW_INTERLEAVED
    print("%s set_params: %d" % (name, r))
    pcms.append((name, p))
for name, p in pcms:
    r = lib.snd_pcm_prepare(p)
    print("%s prepare: %d" % (name, r))
print("voice PCMs open, holding %.0f s" % hold, flush=True)
time.sleep(hold)
for name, p in pcms:
    lib.snd_pcm_close(p)
print("closed")
