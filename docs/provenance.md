# Source provenance and test scope

The driver in `c778_lt6911uxe.c` is the development source tested on 2026-10-29. Its contents are preserved byte-for-byte from that tested revision.

- Upstream: [Linux v6.18, drivers/media/i2c/lt6911uxe.c](https://github.com/torvalds/linux/blob/v6.18/drivers/media/i2c/lt6911uxe.c).
- Original copyright: Intel Corporation, 2023–2025; original GPL-2.0 SPDX declaration retained.
- C778 adaptation: OF matching, optional GPIOs, local paged-regmap CCI equivalents, signal polling, RGB/YUV selection and no-signal queue waiting; a nonpersistent Pi 5 CSI0 overlay was added separately.
- Tested adapted source SHA-256: `70d59ed6c7b0ecfe5d2ea77a507756a31c35f925e33505c3ddd0ebb4d31e565a`.
- Tested upstream-derived binary SHA-256: `eb7ff09d7b9b247f5786023359dd2a71b77dba4341dc4e07ae1c0720db615bf6`.
- Tested DTBO SHA-256: `bbaf81dd09b96016fa3a79c8efb5eb2174aa7e0c6e004f9a8fd2d34250cf6ebc`.

Binary hashes identify the original measurements; a local rebuild may differ due to build paths or toolchain details. The repository distributes source, not a universal prebuilt `.ko`. No Lontium firmware image, vendor flashing tool, legacy factory binary bundle, credentials, SSH helper or device desktop capture is included.

The Makefile builds the same module source plus the overlay. Repository scripts add path handling, host/ABI checks, discovery and clear errors; those conveniences do not extend the tested hardware/mode coverage.

## Historical no-signal failure

An earlier development revision returned `-ENOLINK` during STREAMON when HDMI was absent. This triggered an Oops in the distribution `rp1_cfe_downstream` cleanup path (`csi2_stop_channel`). The Pi was rebooted and that revision was discarded.

The committed revision restores upstream-style queue waiting when input is absent, while timing queries still report no link. A bounded no-input stream then exited cleanly after SIGINT without another Oops. This does not constitute a general fix or safety certification for the distribution CFE error handler. Avoid experimenting with active hotplug or forcing invalid formats on important systems.

## Unresolved limitations

- 4K60 capture logs `DPHY: Datarate 2495 Mbps out of range`. The warning is retained in the measurement JSON. PHY timing/rate configuration and long-term integrity require investigation.
- Current capture metadata reports Raw / ITU-R 601 / full range. HDMI colorimetry/range propagation and calibrated color checks remain incomplete.
- Only one CSI0 path was tested; CSI1, dual-copy capture, split halves, synchronization, 1080p120 and I²S audio are not validated by this repository.
- The 600-frame test does not measure encoded video performance or latency.
- No firmware-version hash was collected in this run. The chip ID alone does not identify a reproducible firmware release; firmware provenance must be added before a production compatibility claim.
