#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Configure an idle CSI0 path from detected timing. Does not change source timing.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/find-path.sh"
c778_find_path
v4l2-ctl -d "$C778_SUBDEV" --query-dv-timings || { echo 'No valid HDMI input. Connect the source and retry.' >&2; exit 1; }
fmt=$(media-ctl -d "$C778_MEDIA" --get-v4l2 "\"$C778_ENTITY\":0" | sed -n 's/.*fmt:\([^ ]*\).*/\1/p')
code=${fmt%%/*}
dimensions=${fmt#*/}
width=${dimensions%x*}
height=${dimensions#*x}
case "$width" in ''|*[!0-9]*) echo 'Invalid detected width.' >&2; exit 1;; esac
case "$height" in ''|*[!0-9]*) echo 'Invalid detected height.' >&2; exit 1;; esac
case "$code" in
 BGR888_1X24) fourcc=RGB3;;
 UYVY8_1X16) fourcc=UYVY;;
 *) echo "Untested media-bus format: $code" >&2; exit 1;;
esac
media-ctl -d "$C778_MEDIA" -l '"csi2":4 -> "rp1-cfe-csi2_ch0":0 [1]'
media-ctl -d "$C778_MEDIA" -V "\"csi2\":0 [fmt:$fmt field:none]"
media-ctl -d "$C778_MEDIA" -V "\"csi2\":4 [fmt:$fmt field:none]"
v4l2-ctl -d "$C778_VIDEO" --set-fmt-video="width=$width,height=$height,pixelformat=$fourcc"
v4l2-ctl -d "$C778_VIDEO" --get-fmt-video
printf 'Media device: %s\nBridge subdevice: %s\nCapture device: %s\n' "$C778_MEDIA" "$C778_SUBDEV" "$C778_VIDEO"
