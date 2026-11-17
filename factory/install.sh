#!/bin/bash
# Run as the desktop user, with sudo available. No kernel or chip firmware changes.
set -euo pipefail
base=$(cd -- "$(dirname -- "$0")/.." && pwd)
[[ $EUID != 0 ]] || { echo 'Run as the desktop user, not root.' >&2; exit 1; }
[[ $base != *' '* ]] || { echo 'Use a checkout path without spaces.' >&2; exit 1; }
for cmd in ffplay ffmpeg aplay arecord dtc wlr-randr python3; do command -v "$cmd" >/dev/null; done
cd "$base"
make -j4
dtc -@ -I dts -O dtb -o factory/c778-audio.dtbo c778-audio.dts
mkdir -p "$HOME/.config/autostart"
[[ ! -e "$HOME/.config/autostart/c778-factory.desktop" ]] || cp -p "$HOME/.config/autostart/c778-factory.desktop" "$HOME/.config/autostart/c778-factory.desktop.backup-$(date +%s)"
printf '[Desktop Entry]\nType=Application\nName=C778 Factory Test\nExec=/usr/bin/python3 %s/factory/factory-run.py\nTerminal=false\n' "$base" > "$HOME/.config/autostart/c778-factory.desktop"
sudo tee /etc/systemd/system/c778-factory-hardware.service >/dev/null <<EOF
[Unit]
Description=C778 factory hardware setup
After=systemd-modules-load.service
Before=display-manager.service
[Service]
Type=oneshot
ExecStart=/bin/bash $base/factory/boot-setup.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable c778-factory-hardware.service
echo 'Installed. Keep this checkout in place. Enable desktop autologin, then reboot.'
