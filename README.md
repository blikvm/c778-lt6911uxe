# C778 / LT6911UXE Linux driver

[English](README.md) | [简体中文](README.zh-CN.md)

Development driver and CSI0 device-tree overlay for the **BliCube C778 HDMI-to-MIPI CSI-2 module on Raspberry Pi 5 Model B**. This repository contains the source used in the 2026-10-29 bring-up, plus build and reproduction scripts.

**Current status:** one CSI0 path delivered a complete **3840×2160 UYVY stream at approximately 60 fps** in a 600-frame, 10-second test. The kernel also reported **`DPHY: Datarate 2495 Mbps out of range`**. This is a development snapshot with known issues, not a production-ready or long-term 4K60 compatibility claim.

## Scope and tested environment

| Item | Tested configuration |
| --- | --- |
| Host | Raspberry Pi 5 Model B Rev 1.0, ARM64 |
| OS | Debian 13.7 / Raspberry Pi kernel packages |
| Kernel | `6.18.50+rpt-rpi-2712` |
| Kernel build | `#1 SMP PREEMPT Debian 1:6.18.50-1+rpt1 (2026-09-11)` |
| Module | C778, LT6911UXE chip ID `0x2102` |
| Control path | CAM/DISP 0 camera I²C bus, address `0x2b` |
| Video path | One four-lane CSI0 path, using the distribution RP1-CFE driver |
| Test source | The Pi's HDMI-A-1 output connected to C778 HDMI input |
| Capture | 3840×2160, UYVY, 16,588,800 bytes/frame |
| Measured result | 600 frames; 59.9992 fps from timestamps; continuous sequence and full-size buffers |

The source starts from the official Linux v6.18 LT6911UXE driver; see [provenance](docs/provenance.md). It is **not** the legacy `anran_*` factory-test stack or a port of the vendor firmware-flashing example.

This snapshot does not validate CSI1, two simultaneous outputs, left/right split capture, synchronization, 1080p120, I²S audio, active-stream hotplug or other kernels. The RV1126B driver is not included in this first Pi 5 snapshot.

## 1. Hardware connection

1. Power off the Pi and C778 before connecting FPC cables.
2. Connect the C778 CSI output being tested to **Pi 5 CAM/DISP 0**, using a compatible four-lane 22-pin cable. Check pin 1 and contact orientation at both ends against the [C778 hardware manual](https://blikvm.com/docs/device-guides/C778/).
3. Supply C778 through its dedicated **5V** power input. Do not inject 5V into a Pi CSI 3.3V pin.
4. Connect an HDMI source to C778 VIDEO-IN. The tested loopback used the Pi's own HDMI output; an independent source can also be used.
5. Boot the Pi and sign in locally or through SSH.

The overlay targets CAM/DISP 0 and expects the bridge at I²C `10-002b`. It does not auto-select between Pi ports or infer C778's MIPI0/MIPI1 firmware assignment. If identification fails, check module power, the selected CSI port and FPC wiring before changing firmware. Do not connect another camera to the same host path.

## 2. Check the kernel and install build tools

Run **on the Pi**, not on your desktop:

```bash
uname -m
uname -r
uname -v
```

The tested architecture is `aarch64` and kernel release is `6.18.50+rpt-rpi-2712`. The loader deliberately rejects other releases. Building against different headers does not make an untested kernel compatible.

```bash
sudo apt update
sudo apt install build-essential git device-tree-compiler v4l-utils kmod
# Use headers matching the kernel you are actually running.
sudo apt install "linux-headers-$(uname -r)"
test -d "/lib/modules/$(uname -r)/build"
```

If that exact header package is no longer available, obtain a matching kernel/header pair through your distribution. Do not force-load a module or blindly downgrade the OS to reuse an old binary. Historical package availability is not guaranteed.

Your account needs `sudo` for module/overlay loading and permission to access video devices. Raspberry Pi OS commonly gives its desktop user membership in the `video` group. If necessary, add the account to that group and sign out/in before continuing.

## 3. Download and build

```bash
git clone https://github.com/blikvm/c778-lt6911uxe.git
cd c778-lt6911uxe
make -j4
```

The build produces:

- `c778_lt6911uxe.ko`: module built against the running kernel headers.
- `overlays/c778-csi0.dtbo`: CSI0 device-tree overlay.

No prebuilt module is committed, no firmware is flashed and no files are installed into the system module tree. `make clean` removes local build products.

## 4. Load temporarily

Stop other camera/capture applications first, then run:

```bash
./scripts/load.sh
```

The loader checks the Pi model, architecture, kernel release and module vermagic, loads standard dependencies and applies the overlay at runtime. It also checks that the bridge actually bound, since successful overlay application alone is not proof of driver detection.

Expected kernel messages include:

```text
C778 bridge identified: chip 0x2102, four lanes, polling; no firmware writes
Using sensor c778_lt6911uxe 10-002b for capture
```

Inspect the graph and HDMI timing:

```bash
./scripts/status.sh
```

With no HDMI source, a timing query reports **no link**. A default pad format is only a placeholder, not detected video. The driver permits a capture queue to wait for input, but the supplied configuration/capture scripts refuse a missing HDMI signal.

## 5. Configure and capture

After connecting the source and allowing its timing to settle:

```bash
./scripts/configure-capture.sh
./scripts/capture.sh 120
```

The scripts discover the media, bridge and capture nodes instead of assuming `/dev/video0`. They copy the bridge format to the CSI receiver and configure the video queue. Currently recognized combinations are `BGR888_1X24` → `RGB3` and `UYVY8_1X16` → `UYVY`; the recorded 4K60 test used **UYVY**.

`capture.sh` captures to `/dev/null`, with verbose sequence/timestamp information and a 20-second deadline. A timeout or nonzero exit is not a successful frame-count test. Re-run configuration while the path is idle after a source timing change. The scripts do not change the source's resolution or refresh rate.

### Save a frame in the tested 4K UYVY mode

Only use this example after `status.sh` confirms 3840×2160 input and configuration confirms UYVY:

```bash
sudo apt install ffmpeg
mkdir -p results
. ./scripts/find-path.sh
c778_find_path
timeout --signal=INT --kill-after=3s 10s v4l2-ctl -d "$C778_VIDEO" \
  --stream-mmap=4 --stream-skip=5 --stream-count=1 \
  --stream-to=results/frame-4k.uyvy
ffmpeg -f rawvideo -pixel_format uyvy422 -video_size 3840x2160 \
  -i results/frame-4k.uyvy -frames:v 1 -update 1 results/frame-4k.png
```

The raw file should be 16,588,800 bytes. Inspect the decoded image for complete content, colors and ordering. Adjusting decoding dimensions does not change the HDMI input. The current colorimetry metadata needs further work; this example does not establish calibrated color accuracy.

## 6. Reboot and recovery

Loading is **temporary**. Neither the module nor overlay is enabled automatically at boot. After a reboot, run `load.sh` and then `configure-capture.sh` again.

To return to the original host boot configuration:

1. Stop capture applications.
2. Reboot the Pi normally.

This removes the runtime module/overlay. No kernel replacement, boot-config edit or firmware rollback is required by this repository. Kernel configuration changes made independently of this repository are outside that statement.


When switching driver revisions, stop capture and reboot before loading the new build; an already-loaded module is not replaced by rebuilding a file.

## Known issues

- **D-PHY warning:** the successful short 4K60 run logged `Datarate 2495 Mbps out of range`. PHY timing/rate setup and long-term integrity still require investigation. Do not suppress the warning or advertise unconditional stable 4K60 support from this result.
- **Color metadata:** capture currently reports Raw / ITU-R 601 / full range. HDMI colorimetry and range propagation are incomplete.
- **No-signal error path:** an earlier, discarded revision that rejected no-input STREAMON triggered an Oops in the distribution CFE error cleanup. The committed version uses upstream-style waiting and passed the bounded no-input stop test. The distribution CFE itself has not been generally fixed or certified.
- **Untested functionality:** dual CSI, split halves, 1080p120, audio, long soak, repeated mode changes, active hotplug and boot persistence remain unvalidated.
- **Firmware provenance:** no firmware-version hash was collected in this run. Chip identity alone does not establish a reproducible firmware release.

See [source provenance and details](docs/provenance.md) and the [original measurement report](evidence/pi5-2026-10-29-summary.json). Short raw capture does not measure encoding performance or end-to-end latency.

## Reporting problems

Include the Pi and C778 revisions, `uname -a`, module source commit, firmware/profile information if known, FPC/port wiring, source timing, `status.sh` output and relevant kernel logs. Remove credentials and unrelated logs before posting. Report D-PHY warnings even when frames arrive.

## License

[GPL version 2](LICENSE). The original driver copyright/SPDX header is preserved. See [provenance](docs/provenance.md) for the upstream file and tested source hash. This repository does not distribute vendor firmware or flashing tools.
