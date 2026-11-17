#!/bin/bash
set -euo pipefail
base=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$base"
bash scripts/load.sh
if ! grep -q C778I2S /proc/asound/cards; then
 dtoverlay "$base/factory/c778-audio.dtbo"
fi
