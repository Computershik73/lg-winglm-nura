# tools

Scripts written while bringing the port up. They are working notes rather
than polished tools: most of them were run from WSL on the PC against the
phone over USB networking (`ssh user@172.16.42.1`, the script sent on stdin)
and assume this repository at `$HOME/lg-winglm-nura`.

Useful ones:

* `device-build.sh` — build the device package with pmbootstrap and copy the
  APKs to the phone.
* `kernel-build.sh`, `gen-kpatch-*.sh` — kernel build and patch generation.
* `diagcap.py`, `diagdec.py` — capture and decode the modem's debug messages
  (`/dev/diag`, `qdsp6m.qdb`).
* `qmiqrtr.py`, `qmiidl.py` — raw QMI over QRTR; dump QMI IDL objects from
  vendor libraries.
* `elfx.py` — annotate `objdump` output (strings, GOT, Android packed
  relocations).
* `volte/` — the VoLTE prototypes (the packaged daemon is in
  `pmaports/device/testing/device-lg-winglm/volte/`).
* `calls-patch/` — sources of the GNOME Calls second-screen dial pad patch.
* `mesa/build-mesa-kgsl.sh` — Mesa with the KGSL backend, built on the phone.
* `acdb/` — ACDB calibration file parsers.
* `edl-restore.ps1` — restore `boot_a` over EDL (Windows, QPST tools).

All of it is GPL-3.0-or-later (see ../LICENSE).
