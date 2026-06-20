#!/usr/bin/env bash
# RECOVERY NET — run from a console (Ctrl+Alt+F3) if the 595.84 .run breaks graphics.
# Removes the upstream .run driver and reinstalls the exact stock Ubuntu driver
# that is working right now, then rebuilds initramfs. Reboot after.
set -x
# 1. Tear down the .run-installed driver (no-op if it never installed)
nvidia-installer --uninstall --silent 2>/dev/null || /usr/bin/nvidia-uninstall --silent 2>/dev/null || true
# 2. (Re)install the stock open driver — plain install works whether it was
#    purged (610 attempt) or merely overwritten. Pulls back all 595 deps.
apt-get update
apt-get install -y \
  nvidia-driver-595-open=595.71.05-0ubuntu0.26.04.1 \
  linux-modules-nvidia-595-open-generic \
  linux-modules-nvidia-595-open-"$(uname -r)" 2>/dev/null || \
  apt-get install -y nvidia-driver-595-open
# 3. Rebuild initramfs so the stock module loads at boot
update-initramfs -u -k all
echo
echo "=== RECOVERY DONE — reboot now:  sudo reboot ==="
