# VoLTE on the LG Wing

LG's modem firmware for this phone has **no IMS client** (no Qualcomm
IMSA/IMSS QMI services). On Android, LG's IMS application (`Ims6.apk` +
`libims.lge.so`) does SIP on the application processor and drives a media
engine that runs **inside the modem** ("MMPF") through an LG vendor QMI
service. This port replaces the Android side with `winglm-volte`
(`pmaports/device/testing/device-lg-winglm/volte/`), a Python daemon:

```
GNOME Calls ──SIP (127.0.0.1:5070)──> winglm-volte ──SIP over IPsec──> P-CSCF
                                          │ QMI 703 (LG VSS IMS)
                                          └──> modem: MMPF media engine ──RTP──> network
                                                   │ voice services (VS, VSID 0x11C05000)
                                                   └──> ADSP voice path (VoiceMMode1) → earpiece/mic
```

Everything here was tested on **MegaFon (Russia, MCC 250 MNC 02)**.

## 1. IMS PDN over the downstream IPA

ModemManager refuses `rmnet_ipa0` ("Unsupported QMI kernel driver"), so the
daemon brings the PDN up itself, like Qualcomm's netmgrd (`ipadata.py`):

1. `rmnet_ipa0` up; extended ioctl `0x89FD`: `SET_EGRESS_DATA_FORMAT`
   (MAP|MUX) and `SET_INGRESS_DATA_FORMAT` (MAP|DEAGG|DEMUX|CSUM|AGG,
   31668 bytes, 31 packets) — **once per boot**.
2. `ip link add link rmnet_ipa0 name rmnet_dataN type rmnet mux_id N
   ingress-deaggregation on ingress-mapv5-checksum on`, then
   `ADD_MUX_CHANNEL` and `GET_EP_PAIR` (consumer 2, producer 16).
3. QMI DPM *open port* with the hardware data port only (embedded, iface 1).
   Adding the `DATA5_CNTL` control port hangs the AP.
4. QMI WDA *set data format*: raw-IP, UL QMAP (5), DL QMAPv5 (9),
   31 packets / 31668 bytes, endpoint embedded/1.
5. QMI WDS: bind mux, set IP family, start network, get runtime settings.

Pitfalls: plain QMAP downlink (no checksum offload) panics the kernel on the
first packet (the DT sets `qcom,wan-use-skb-page`, rmnet then needs the
MAPv5 frag path). Setting up IPA before the modem has attached also panics
once traffic flows: the daemon waits for uptime ≥ 120 s and LTE PS attach,
and a guard file disables VoLTE for the next boot after a crash.

MegaFon's IMS APN is `ims`, **IPv4 only** (IPv6 gets ESM cause #50). The WDS
profile needs TLV `0x1F` (P-CSCF address via PCO = 1) and `0x22` (IM CN flag
= 1); the network then returns two P-CSCF addresses.

## 2. Registration

* Identities from the ISIM, read over a QMI UIM logical channel (open
  `0x42`, APDU `0x3B`, close `0x3F`): IMPI `IMSI@ims.mnc002.mcc250.3gppnetwork.org`,
  IMPU and home domain.
* `AKAv1-MD5` digest; the response is computed by the ISIM
  (`AUTHENTICATE`, `00 88 00 81`), RES used as binary.
* IPsec (RFC 3329): transport-mode ESP, `hmac-sha-1-96` with IK + 4 zero
  bytes, null encryption; the P-CSCF used ports 9950/9900.
* **The P-CSCF drops fragmented ESP**: keep SIP over UDP below ~1250 bytes,
  otherwise use TCP.
* Expires 7200 (Min-Expires 3600), refresh at half.
* **Re-authentication:** MegaFon answers every other re-REGISTER with
  `401` (new AKA challenge, no Security-Server). Answer it *within the same
  registration*: same Call-ID, next CSeq, fresh AKA response, keep the
  existing SAs → `200`. Do not re-register unprotected with the old Call-ID
  (→ `400`), do not send unprotected REGISTERs while SAs exist (ignored), do
  not offer new SPIs in a re-REGISTER (never answered).
* Always de-register on shutdown (a minimal REGISTER with `Expires: 0`),
  otherwise incoming calls go to a dead contact.

## 3. Calls

The daemon is a back-to-back user agent. GNOME Calls registers to it as a
plain SIP account (`winglm-volte-calls` writes the account and its dummy
password into the session keyring).

* MO: `INVITE tel:+7…` (TCP) → `183` (reliable, SDP) → `PRACK` → `180` →
  `200` → `ACK`.
* MT: preconditions handled (`183` with `a=curr/des:qos`, `UPDATE`), then
  Calls rings.
* Codecs offered: AMR-WB and AMR, octet-aligned and bandwidth-efficient,
  telephone-event 8/16 kHz. MegaFon chose AMR-NB in all tested calls.

## 4. Media in the modem ("MMPF")

The protocol below was recovered from `libimsmmpf.lge.so`
(`MMPF_CP_IF`) and `libims.lge.so` (`AudioAdaptor`) of the Android
firmware, and checked against the modem's own debug messages.

### Transport

QMI service **703** (`lge_ims`), message **0x060C**. TLV `0x01` is a fixed
**300-byte** blob, both as request (AP → modem) and as indication
(modem → AP). (Message `0x060D` exists but is not used for media.)

Each blob: a 32-byte header + up to 220 bytes of data; longer messages are
split, `offset` counts data bytes.

| Offset | Field |
| --- | --- |
| 0 | `u32 type` |
| 4 | `u32 last` (1 on the final chunk) |
| 8 | `u32 len` (data bytes in this chunk) |
| 12 | `u32 offset` |
| 16 | `u32 header size` (32) |
| 20 | `u32 session` (0…31 media, 32…63 socket bridges) |
| 24 | `u32 seq` |
| 28 | `u32 0` |

AP → modem types: `0` create session, `1` destroy, `2` set property,
`3` request, `4` get state, `5` clear all (sent once at start-up),
`7`/`8`/`9` create/destroy socket bridge and bridge data.

Modem → AP types: `0` response (`u32 request, u32 result`), `1` notify
(`u32 code`), `2` modem IP address, `3`/`4` socket bridge, `5` socket data,
`6` L3 data, `9` received packet counts (`u32 rtp, rtcp_sr, rtcp_rr`),
`11` RTT data, `16` socket interface id.

### Properties

A property is a 12-byte header (`u32 type, u32 mode, u32 0`) followed by its
data; total sizes: TXSOURCE 284, CODEC 416, TRANSPORT 204, NETWORK 280,
DISPLAY 52, DEBUG 276. `mode`: **TX = 0, RX = 1**. Data offsets:

**NETWORK (3)**

| Data offset | Field |
| --- | --- |
| 0 | transport: 2 = LRTP |
| 4, 8 | local / remote address is IPv6 |
| 12 | local IP, `char[46]` |
| 58 | remote IP, `char[46]` |
| 104 | RTP: `u32 0, u32 local port, u32 remote port, u8 TOS` |
| 120 | RTCP: same layout |
| 136 | `s32` PDP profile number (LTE) |
| 140 | APN, `char[64]` |
| 204 | `s32` PDP profile (3GPP2), −1 |
| 208 | socket position: **1 = "cp"** (the modem opens the socket on the IMS PDN), 2 = "ap" |

With socket position 1 the modem joins the PDN through its own data
services (by profile number or APN), binds the RTP/RTCP ports and installs
IP filters, so the AP never sees the media packets.

**TRANSPORT (2)**: `0` transport (2), `4` local payload type, `8` remote
payload type, `12` clock rate, `16` ptime, `20` payload header mode
(0 octet-aligned, 1 bandwidth-efficient), `24` DTMF payload type, `28` DTMF
enabled, `32..44` DTMF durations, `48` DTMF clock rate, `60/64` RTP timeout
check type / threshold, `164` SRTP enabled (keys follow).

**CODEC (1)**: `0` codec (**AMR 3, AMR-WB 4, EVS 8**), `4` codec option (2),
`8` AMR mode-set bitmask (bit *n* = mode *n*), `12` "SCR off" (DTX disabled),
`28/32/36` jitter buffer init/min/max in frames (LG uses 4/4/9 for
MegaFon), EVS parameters in between.

**TXSOURCE (0)**: `0` source, 1 = live (microphone through the voice path).

### Requests

24 bytes: `u32 request, u32 mode, …0`. **START = 2, STOP = 3**, PAUSE 4,
RESUME 5, SEND_DTMF 21 (140 bytes, not used yet), RESET 28.

### A call

```
clear all (once) → create session 0
for mode in RX, TX: set NETWORK, TRANSPORT, CODEC
set TXSOURCE (TX)
request START RX, START TX
... call ...
request STOP TX, STOP RX → destroy session 0
```

The modem's voice services then request a vocoder on **VSID 0x11C05000**
(VoiceMMode1). The AP has to provide the matching voice session exactly as
for a 2G/3G call: set the call route (UCM verb "Voice Call") and open +
prepare both directions of the VoiceMMode1 PCM (`hw:0,2`). From there the
audio goes through the ADSP voice path: earpiece/speaker/mic, and the same
DSP processing as a circuit-switched call.

## 5. Debugging the modem

`tools/diagcap.py` captures the modem's F3 debug messages from `/dev/diag`
(memory-device mode); `tools/diagdec.py` decodes them with the modem's
`qdsp6m.qdb` (zlib-compressed string table on the modem partition). The
`MMPF`, `vs_*` and `qmi_vss_*` messages show what the media engine does.
