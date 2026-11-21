# LG Wing hardware notes

Facts found while bringing the port up. Most of them cost a reboot or a
crash to discover.

## Boot

* The stock ABL has no bootloader fastboot: `adb reboot bootloader` boots
  Android. Only **fastbootd** (in recovery) works: `adb reboot fastboot`.
  Keep `recovery_a` stock.
* EDL (9008) on stock firmware: `adb reboot edl` is compiled out. From power
  off, hold Vol Down + Power while repeatedly tapping Vol Up.
* QFIL reads the GPT only for LUN 0,1,2,4,5 and hides 1-sector partitions;
  map the dumps with the `fh_gpt_*` files.
* ABL uses only the 512-byte cmdline field of the boot image header (≤ 511
  characters); `pmos_*_uuid` come last and get cut off otherwise.
* LG copies the last kernel log into the `pstore` partition (LUN 0): read it
  with `strings` after a crash. ABL prints the reboot reason.

## Display

* Two command-mode DSC panels: DSI-1 (SW43103, 1080×2460) and DSI-2
  (RM692C9, 1080×1240). No fbdev/fbcon output; KMS clients only.
* ABL leaves DSI-1 in continuous splash. With `video=DSI-1:d`, splash handoff
  used `list_first_entry` on an empty mode list and DSI-2 never got a frame
  — kernel patch 0001 handles the handoff.
* Both panels report the same EDID name ("QCM 0x0001"); patch 0003 puts the
  panel model into the EDID name so the compositor can tell them apart.
* Never force `video=Virtual-1:d` (the SDE writeback connector): msm_drm probe
  fails → no USB networking → watchdog reboot loop. phoc skips it instead.
* wlroots computed 24.3 Hz for the cmd-mode panels from the DSI link clock;
  phoc takes the refresh from vrefresh. KGSL has no implicit fences: phoc
  does a `glFinish` when there is no sync timeline (otherwise black stripes).
* Screen blanking (Phosh) disables the outputs in wlr-output-management; a
  disabled head reports no position, scale or transform.

## Swivel

* State: `/sys/class/smartcover/swivel/state` (0 half, 1 closed, 2 open);
  hall GPIOs 138/139. `gpio-keys` reports it only as **SW_LID** — UPower must
  ignore the lid (`IgnoreLid=true`), otherwise GNOME Settings treats both
  built-in screens as unusable.
* The swivel touchscreen (SW42000) only enables its IRQ in the open
  position; kernel patch 0002 adds `gpio_keys.swivel_force=2`.
* "T" position: DSI-1 transform 90, DSI-2 centred below it, scale 3 →
  360×413 logical pixels.

## GPU

* KGSL works with `a650_sqe.fw`, `a650_gmu.bin` and `a620_zap.*` from the
  vendor partition. Mesa must be built with `-Dfreedreno-kmds=kgsl`, plus
  GLX and GLES1 so that every library Alpine links against libgallium comes
  from the same build.

## Audio

* Card `lito-mtp-snd-card` appears after the ADSP boots. The TFA9878 speaker
  amplifier needs its container file from the vendor partition before that.
  TFA speaker protection does not run (it needs Android's HAL).
* UCM must route defaults inside the verb (a DPCM front end does not open
  otherwise). Voice = VoiceMMode1 front end `hw:0,2`; preparing both
  directions starts the DSP voice session.
* Earpiece crackle: WCD938x **"RX HPH Mode" starts at CLS_H_NORMAL**, in
  which the Class-H port is never connected while the RX path sends Class-H
  data. LG sets `CLS_H_ULP` (and `RX_HPH_PWR_MODE ULP`) at boot; the UCM does
  it before enabling the earpiece. "EAR PA GAIN" defaults to +6 dB → 0 dB.
* Kernel bug: `snd_soc_put_volsw_sx` rejects values above `max` although the
  control reports 0…124, so RX digital volume cannot reach 0 dB from
  userspace — patch 0005. Don't write `_sx` volume controls on an unpatched
  kernel.
* PulseAudio timer scheduling picked 0.5 s periods on the Q6 PCMs (position
  is reported per period): udev sets `PULSE_NO_TIMER_SCHED=1` for the card.

## Modem, SIM, data

* No in-kernel QRTR name server: userspace `qrtr-ns`. CAF qrtr drops
  NEW_SERVER messages naming node 0 once the modem (node 0) exists → qrtr
  fork. pd-mapper and tqftpserv look in the firmware search path (there is no
  `/sys/class/remoteproc`).
* RF card MBN is fetched over TFTP from `/readonly/firmware/image/modem_pr/…`;
  without it the modem stays offline.
* The USIM stays "detected" until an AP client sends LG VSS common (QRTR
  service 800) message `0x0602` with TLV1 = `u32 1` ("vss init") —
  `winglm-vss`.
* rmtfs works on copies of the EFS partitions in `/var/lib/rmtfs`; the
  partitions themselves are only read.
* Mobile data over IPA: see [volte.md](volte.md#1-ims-pdn-over-the-downstream-ipa).

## Wi-Fi and Bluetooth

* WCN3991 Wi-Fi (firmware in the modem) needs the board data and calibration
  report over WLFW QMI (`winglm-wlfw-bdf`, a cnss-daemon replacement),
  `echo 1 > /dev/ipa` and `echo ON > /dev/wlan` first.
* Bluetooth on `/dev/ttyHS0`: the kernel has no `BT_HCIUART`; `winglm-bt`
  does the Qualcomm setup in userspace (power via the bt_power rfkill, reset
  pulses, RTS/CTS, 3 Mbaud, `crbtfw32.tlv` + `crnv32u.bin`), then N_HCI/H4.
  The controller keeps Qualcomm in-band sleep on → kernel patch 0004.
* NetworkManager 1.58 adds prefix routes with gateway 0.0.0.0, which this
  kernel rejects → a dispatcher script adds the routes.

## Misc

* The short power-key press defaulted to power-off in elogind, and shutting
  the display down then hung the SDE driver → elogind ignores the power key,
  the shell handles it.
* polkit: `pidfd_open` exists (Android backport) but polkitd started as root
  cannot read `/proc/self/fdinfo` → run it as `polkitd`.
* Cameras (Spectra/CamX) and the fingerprint sensor (Egistec + TA) are not
  feasible outside Android.
