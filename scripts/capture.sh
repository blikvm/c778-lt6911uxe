#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Bounded delivery check, not a claim of long-term or color correctness.
set -eu
frames=${1:-120}
case "$frames" in ''|*[!0-9]*) echo 'Usage: ./scripts/capture.sh [positive-frame-count]' >&2; exit 1;; esac
[ "$frames" -gt 0 ] || { echo 'Frame count must be positive.' >&2; exit 1; }
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/find-path.sh"
"$here/configure-capture.sh"
c778_find_path
printf 'Capturing %s frames from %s to /dev/null (20-second deadline).\n' "$frames" "$C778_VIDEO"
timeout --signal=INT --kill-after=3s 20s v4l2-ctl --verbose -d "$C778_VIDEO" \
 --stream-mmap=4 --stream-count="$frames" --stream-poll --stream-to=/dev/null
printf 'Requested frame count completed. Inspect sequence, timestamps and kernel logs.\n'
