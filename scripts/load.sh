#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Runtime development loader: no module-tree install, boot edits or flash writes.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project"
expected=6.18.50+rpt-rpi-2712
[ "$(uname -r)" = "$expected" ] || { printf 'Unsupported kernel: expected %s; got %s\n' "$expected" "$(uname -r)" >&2; exit 1; }
[ "$(uname -m)" = aarch64 ] || { echo 'This loader requires aarch64.' >&2; exit 1; }
model=$(tr -d '\000' < /proc/device-tree/model)
case "$model" in 'Raspberry Pi 5 Model B'*) ;; *) echo 'This overlay is for Raspberry Pi 5 Model B.' >&2; exit 1;; esac
for file in c778_lt6911uxe.ko overlays/c778-csi0.dtbo; do
 [ -f "$file" ] || { printf 'Missing %s; run make first.\n' "$file" >&2; exit 1; }
done
modinfo_cmd=$(command -v modinfo || true)
[ -n "$modinfo_cmd" ] || modinfo_cmd=/sbin/modinfo
vermagic=$("$modinfo_cmd" -F vermagic ./c778_lt6911uxe.ko)
[ "${vermagic%% *}" = "$expected" ] || { echo 'Module vermagic does not match the running kernel.' >&2; exit 1; }
sudo /sbin/modprobe -a v4l2_async v4l2_dv_timings v4l2_fwnode regmap_i2c
if ! grep -q '^c778_lt6911uxe ' /proc/modules; then
 sudo /sbin/insmod ./c778_lt6911uxe.ko
fi
if ! sudo dtoverlay -l | grep -q 'c778-csi0'; then
 sudo dtoverlay "$PWD/overlays/c778-csi0.dtbo"
fi
# Applying an overlay can succeed even if the driver probe fails.
count=0
while [ ! -L /sys/bus/i2c/devices/10-002b/driver ] && [ "$count" -lt 5 ]; do
 sleep 1
 count=$((count + 1))
done
bound=$(readlink -f /sys/bus/i2c/devices/10-002b/driver 2>/dev/null || true)
case "$bound" in */c778_lt6911uxe) ;; *) echo 'C778 did not bind. Check module power, CAM/DISP 0 cabling and dmesg.' >&2; exit 1;; esac
printf 'C778 development driver is bound on CSI0.\n'
printf 'After HDMI timing settles, run ./scripts/configure-capture.sh\n'
printf 'The overlay/module are temporary and are removed by reboot.\n'
