# Pi 5 I²S audio and factory loopback / 音频与产测

This is an opt-in development test on Pi 5, aarch64, kernel `6.18.50+rpt-rpi-2712`, with an existing graphical Raspberry Pi OS desktop. It retains the repository video driver and distribution RP1-CFE. It does not flash C778 firmware or replace the kernel.

## Wiring / 接线

Power down before changing wiring. C778 has dedicated 5V power; use compatible four-lane 22-pin FPC to CAM/DISP 0. HDMI0 → monitor; HDMI1 → C778 VIDEO-IN. The current full-frame firmware supplies one complete UYVY image over CSI0.

| C778 | BCM GPIO | Physical pin |
| --- | --- | --- |
| SCK / SCLK | 18 | 12 |
| WFS / WS | 19 | 35 |
| SD / SDOUT | 20 | 38 |
| GND | GND | e.g. 39 |

C778 supplies bit/frame clocks; Pi uses `i2s_clk_consumer`. Do not load an overlay that makes Pi drive these clocks. MCLK is not used in this receiver setup. `linux,spdif-dir` is a generic capture endpoint for this fixed-format test; it does not turn the physical input into S/PDIF, detect HDMI sample rates or represent a full LT6911UXE ALSA codec driver. No I²C audio register configuration is performed.

## Manual audio test

Run from the repository, after building/loading the video driver:

```bash
sudo apt install alsa-utils ffmpeg python3 wlr-randr fonts-droid-fallback
dtc -@ -I dts -O dtb -o factory/c778-audio.dtbo c778-audio.dts
sudo dtoverlay "$PWD/factory/c778-audio.dtbo"
arecord -l
arecord -D hw:C778I2S,0 -f S32_LE -r 48000 -c 2 -d 3 capture.wav
```

Only run recording when no other test owns the device. Listing a sound card does not prove audio is present. The factory source sends 48 kHz stereo PCM; other sample rates, compressed audio and channel counts are unvalidated. Do not label arbitrary material failed merely because it lacks these particular test tones.

## Desktop factory startup / 产测自启动

Use a checkout path without spaces; keep the checkout in place. Install as the desktop user:

```bash
bash factory/install.sh
sudo reboot
```

Enable desktop autologin through Raspberry Pi OS configuration beforehand. This installer does not change login/security settings. Remove or disable any older C778 desktop launchers and conflicting camera/audio programs first. The installer backs up its prior desktop entry but does not stop already running old test processes; reboot completes the change.

A root oneshot system service loads video and audio overlays; a desktop entry starts the user test. HDMI1 is deliberately cycled off/on once to reacquire source timing, then set to 4K60. The validated monitor was 1280×720; the dual-screen layout/fullscreen selection must be checked on a different monitor. A moving color-bar source has frame/time counters and a large audio label. Green requires recent valid left=1000 Hz and right=1500 Hz signals; red covers silence, wrong tones, swapped channels, capture errors, timeouts and stale results (>6 s). This is a signal-presence/channel test, not calibrated fidelity or A/V synchronization validation.

Captured audio is replayed on HDMI0 in one-second segments, with gaps and delay. Preview is not a latency benchmark. Runtime status, PCM and logs are under `~/.local/state/c778-factory/`; player logs are truncated above 8 MiB (collect evidence separately for long runs). The supervisor restarts exited processes but does not prove correct pixels or recover every hung video path.

To remove autostart:

```bash
bash factory/uninstall.sh
sudo reboot
```

Restore a backed-up desktop entry manually if needed. Reboot removes the runtime overlays. It does not delete captured results.

## Validation and remaining work / 验证边界

See `../reboot-report.txt` for 10 distinct warm boots of the earlier left-channel detector. Those checks verify services, active player/log updates and recent 1000 Hz detection, not image correctness, continuous video sequence or right-channel operation. The newer stereo classifier has tests for missing/swapped/duplicated channels; its device validation is recorded separately.

D-PHY `Datarate 2495 Mbps out of range` remains unresolved. Do not suppress it or claim production-grade long-term 4K60. Cold-power starts, active cable replacement, repeated mode changes, long soak, calibrated colors/audio and A/V synchronization remain additional acceptance work.

中文要点：这是可选的 Pi 5 固定格式产测方案，视频 C 驱动未改；音频通过独立 I²S 接收 overlay 和 ALSA 采集。两个声道必须分别检出指定测试音才显示绿色。旧版十次重启记录与新版双声道验证分开保存，不代表完整量产认证。

## Stereo revision device result (2026-11-17)

The packaged installer was run on the same Pi and one additional reboot completed. Both full-screen players resumed. S32_LE 48 kHz capture measured left 1000 Hz (RMS ≈0.07071) and right 1500 Hz (RMS ≈0.07071); see `../stereo-device-result.json`. This one reboot is separate from the ten earlier boots. Unit tests reject left/right silence, swapped channels and duplicated 1000 Hz channels. Physical right-channel fault injection and cold boot remain untested.
