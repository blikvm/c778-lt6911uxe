#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/find-path.sh"
c778_find_path
printf 'Kernel: '; uname -r
printf 'Media: %s\nBridge: %s\nCapture: %s\n' "$C778_MEDIA" "$C778_SUBDEV" "$C778_VIDEO"
media-ctl -d "$C778_MEDIA" -p
v4l2-ctl -d "$C778_SUBDEV" --query-dv-timings
