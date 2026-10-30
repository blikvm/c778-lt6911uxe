#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Shared read-only discovery. Deliberately require the tested single-path entity.
c778_find_path() {
 C778_ENTITY='c778_lt6911uxe 10-002b'
 C778_MEDIA=''
 for candidate in /dev/media*; do
  [ -e "$candidate" ] || continue
  if media-ctl -d "$candidate" -p | grep -Fq "$C778_ENTITY"; then
   C778_MEDIA=$candidate
   break
  fi
 done
 [ -n "$C778_MEDIA" ] || { echo 'C778 CSI0 media path not found.' >&2; return 1; }
 C778_SUBDEV=$(media-ctl -d "$C778_MEDIA" -e "$C778_ENTITY")
 C778_VIDEO=$(media-ctl -d "$C778_MEDIA" -e rp1-cfe-csi2_ch0)
 [ -c "$C778_SUBDEV" ] && [ -c "$C778_VIDEO" ] || { echo 'Capture/subdevice node is missing.' >&2; return 1; }
 export C778_ENTITY C778_MEDIA C778_SUBDEV C778_VIDEO
}
