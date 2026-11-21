# LG Wing (LM-F100N, "winglm") postmarketOS port

- `pmaports/` - postmarketOS packages: `device/testing/device-lg-winglm`
  (device package and subpackages: phosh, dsp, volte, ...),
  `device/testing/linux-lg-winglm` (kernel), `temp/phosh`.
  Build: copy into pmbootstrap's pmaports, `pmbootstrap build device-lg-winglm`.
- `aports/` - Alpine package forks with Wing patches (phosh, phoc, stevia,
  glib, callaudiod, qrtr, qrtr-ns, pd-mapper, tqftpserv); built natively on
  the phone with abuild (`~/aports/<pkg>` there).
- `tools/` - bring-up scripts and prototypes (QMI/IMS/VoLTE, diag, ACDB,
  ...), run from WSL against the phone over USB networking.
