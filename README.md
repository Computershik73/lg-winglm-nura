# LG Wing (LM-F100N, "winglm") — postmarketOS port

A postmarketOS port for the LG Wing (Snapdragon 765G / SM7250 "lito", the
phone with the swivel screen), running Phosh on both screens with the
downstream 4.19 kernel. Developed and daily-tested on an LM-F100N (Korean
model) on the Russian operator MegaFon.

[Русская версия](README.ru.md)

> **Status: works as a phone.** Calls (2G/3G and VoLTE), Wi-Fi, Bluetooth,
> audio, GPU acceleration and both screens work. See the table below for what
> is missing or untested. Expect rough edges: this is a downstream kernel
> port with a lot of reverse-engineered glue.

## What works

| Area | Status |
| --- | --- |
| Boot, USB networking (RNDIS) | ✅ |
| Main screen (SW43103, 1080×2460) + touch | ✅ |
| Swivel screen (RM692C9, 1080×1240) + touch | ✅ (both panels at once; DSI-2 follows the swivel) |
| Swivel ("T" position): main screen rotates, swivel screen below | ✅ (`winglm-swivel`) |
| Phosh on both screens (home bar, app grid and lock-screen keypad on the swivel screen) | ✅ (Phosh/phoc forks) |
| On-screen keyboard on either screen | ✅ (stevia fork) |
| GPU (Adreno 620): Vulkan (turnip), GL/GLES (zink / freedreno on KGSL) | ✅ (Mesa built with the KGSL backend) |
| Wi-Fi (WCN3991) | ✅ |
| Bluetooth (WCN3991) | ✅ |
| Audio: speaker, earpiece, microphone | ✅ |
| Wired headset | ❔ routes exist, untested |
| Modem, SIM, LTE registration (ModemManager) | ✅ |
| SMS, USSD | ❔ untested |
| Voice calls 2G/3G (CS) | ✅ |
| VoLTE (outgoing and incoming, AMR/AMR-WB), audio in the modem DSP | ✅ (own IMS client, see [docs/volte.md](docs/volte.md)) |
| Calls: dial pad on the swivel screen while it is open | ✅ (GNOME Calls fork) |
| Brightness of both panels | ✅ |
| Settings → Displays with the swivel closed | ✅ |

### Not working / not done yet

See the issue tracker for the current state; at the time of writing:

* Suspend (s2idle) — not working on this kernel yet.
* Mobile data for the user (internet over LTE) — the data path works
  (used for IMS), but NetworkManager/ModemManager do not manage it yet.
* In-call volume buttons — need kernel r6 (`linux-lg-winglm`, patch 0005).
* VoLTE: DTMF and the mute button with media in the modem; automatic fallback
  to 2G/3G when IMS is not registered.
* ACDB audio calibration (Android's echo cancellation / noise suppression
  tuning) is not loaded.
* Cameras and the fingerprint sensor (Qualcomm CamX / TEE) — not planned.

## Repository layout

```
pmaports/device/testing/device-lg-winglm   device package + subpackages
    -phosh   swivel handling, screen brightness, GSettings overrides
    -dsp     ADSP/modem/Wi-Fi/Bluetooth bring-up services, audio UCM
    -volte   IMS/VoLTE daemon (winglm-volte) and its GNOME Calls account
pmaports/device/testing/linux-lg-winglm    kernel (LineageOS 4.19 + patches)
aports/<pkg>      forks of Alpine packages with Wing patches (phosh, phoc,
                  stevia, calls, glib, callaudiod, qrtr, qrtr-ns, pd-mapper,
                  tqftpserv), built natively on the phone with abuild
docs/             technical notes (VoLTE / IMS / modem media, hardware)
tools/            bring-up scripts, debugging tools and prototypes
```

## Building

### Device package and kernel (on a PC, pmbootstrap)

```sh
pmbootstrap init                        # device: lg-winglm (after copying below)
cp -r pmaports/device/testing/device-lg-winglm pmaports/device/testing/linux-lg-winglm \
      "$(pmbootstrap config aports)/device/testing/"
pmbootstrap checksum device-lg-winglm linux-lg-winglm
pmbootstrap build device-lg-winglm
pmbootstrap build linux-lg-winglm
```

### Alpine forks (on the phone)

The forks in `aports/` are built natively on the device (pmbootstrap's
cross-compilation did not work for them, QEMU was too slow):

```sh
# on the phone, with network access
sudo apk add alpine-sdk && abuild-keygen -a -i
mkdir -p ~/aports && cp -r aports/<pkg> ~/aports/
cd ~/aports/<pkg> && abuild -r          # packages: ~/.local/share/abuild/aports/aarch64
sudo apk add ~/.local/share/abuild/aports/aarch64/<pkg>-*.apk
```

Alpine updating one of these packages replaces the fork; rebuild it then.

### GPU (Mesa with KGSL)

Alpine's Mesa has no KGSL backend. `tools/mesa/build-mesa-kgsl.sh` builds the
same Mesa version on the phone into `/opt/mesa-kgsl` (turnip + freedreno on
KGSL, zink for GL).

## Installing

**Read this first.** The stock LG ABL has no bootloader fastboot mode: only
*fastbootd* (in the recovery partition) works, reached with
`adb reboot fastboot` from Android or the stock recovery. Keep `recovery_a`
stock: it is the way back to fastbootd. Make a full backup (QFIL/EDL) before
flashing anything; `tools/edl-restore.ps1` restores `boot_a` over EDL.

* The rootfs goes to the userdata partition (this wipes Android's data).
* The kernel command line must stay under 511 characters: LG's ABL only uses
  the boot image header's cmdline field, an overlong one cuts off the root
  partition UUID.
* Never put `video=Virtual-1:d` on the command line (boot loop).

The phone's own firmware (modem, ADSP, Wi-Fi, GPU, audio amplifier) is used
from its partitions at runtime; no LG binaries are part of this repository.

## VoLTE

LG's modem firmware has no IMS client: on Android, LG's IMS app does SIP on
the application processor and drives a media engine inside the modem. This
port has its own IMS client (`winglm-volte`): it brings up the IMS PDN, does
ISIM AKA authentication and IPsec, registers, and acts as a SIP gateway for
GNOME Calls. Call audio runs in the modem (LG's "MMPF" engine) and the DSP
voice path, like on Android. Tested on MegaFon (Russia); other operators may
need different settings. Details: [docs/volte.md](docs/volte.md).

## Reverse engineering

The IMS/VoLTE parts, the modem media protocol and several bring-up steps were
worked out from LG's proprietary Android libraries and the modem's debug
messages, for interoperability with hardware the owner already has. The
findings are documented in `docs/`; no proprietary code or data is included.

## License

Our code (scripts, daemons, tools, documentation) is licensed under the
GNU General Public License v3.0 or later — see [LICENSE](LICENSE). Patches to
other projects (kernel, Phosh, phoc, GNOME Calls, …) are under the license of
the project they patch.

No warranty: flashing a phone can brick it. You do this at your own risk.
