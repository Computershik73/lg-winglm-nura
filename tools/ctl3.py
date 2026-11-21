#!/usr/bin/env python3
"""Write a 3-value voice control (value, session id, ramp) through alsa-lib: ctl3.py NAME VALUE [VSID]"""
import ctypes, sys
lib = ctypes.CDLL("libasound.so.2")
name, val = sys.argv[1], int(sys.argv[2])
vsid = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0xffffffff
ctl = ctypes.c_void_p()
assert lib.snd_ctl_open(ctypes.byref(ctl), b"hw:0", 0) == 0
lib.snd_ctl_elem_id_sizeof.restype = ctypes.c_size_t
lib.snd_ctl_elem_value_sizeof.restype = ctypes.c_size_t
eid = ctypes.create_string_buffer(lib.snd_ctl_elem_id_sizeof())
v = ctypes.create_string_buffer(lib.snd_ctl_elem_value_sizeof())
lib.snd_ctl_elem_id_set_interface(eid, 2)  # MIXER
lib.snd_ctl_elem_id_set_name(eid, name.encode())
lib.snd_ctl_elem_value_set_id(v, eid)
lib.snd_ctl_elem_value_set_integer(v, 0, ctypes.c_long(val))
lib.snd_ctl_elem_value_set_integer(v, 1, ctypes.c_long(vsid))
lib.snd_ctl_elem_value_set_integer(v, 2, ctypes.c_long(0))
r = lib.snd_ctl_elem_write(ctl, v)
lib.snd_strerror.restype = ctypes.c_char_p
print("%s=%d vsid=%#x: %s" % (name, val, vsid, "ok" if r >= 0 else lib.snd_strerror(r).decode()))
