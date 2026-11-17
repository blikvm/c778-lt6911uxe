#!/bin/bash
set -euo pipefail
sudo systemctl disable --now c778-factory-hardware.service
sudo rm /etc/systemd/system/c778-factory-hardware.service
sudo systemctl daemon-reload
rm -f "$HOME/.config/autostart/c778-factory.desktop"
echo 'Autostart removed. Reboot to stop the running test and remove runtime overlays. Restore any previous desktop entry from its backup if required.'
