# Pi 5 measurement evidence

`pi5-2026-10-29-summary.json` is the original machine-readable 600-frame result. It preserves the D-PHY warning alongside successful frame delivery; it is not an unconditional PASS report.

Environment: Raspberry Pi 5 Model B Rev 1.0, Debian 13.7 ARM64, kernel `6.18.50+rpt-rpi-2712`, build `#1 SMP PREEMPT Debian 1:6.18.50-1+rpt1 (2026-09-11)`.

Kernel-notes SHA-256: `57a658ba7454b23f77d8861d840694fb4e485a29038621bd6a55a07765296a50`.

The Pi's HDMI-A-1 output was looped into C778. The stream was 3840×2160 UYVY with 16,588,800 bytes per frame. A separate frame was decoded and visually checked for a full desktop, but is omitted from the public repository. This was not a calibrated color test.

See [source provenance and known issues](../docs/provenance.md) for exact source hashes, the historical no-signal failure and untested features.
