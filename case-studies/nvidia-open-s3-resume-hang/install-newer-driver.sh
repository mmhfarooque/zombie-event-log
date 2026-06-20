#!/usr/bin/env bash
# Install NVIDIA 610.43.02 (open module). Run from a TEXT CONSOLE (Ctrl+Alt+F3):
#     sudo bash ~/610.sh
# Handles everything silently, rebuilds initramfs, and reboots on success.
# If the install FAILS it does NOT reboot and tells you the recovery command.

RUN=/home/USER/DEV/nvidia-resume-fix/NVIDIA-Linux-x86_64-610.43.02.run
RECOVERY=/home/USER/DEV/nvidia-resume-fix/RECOVERY-restore-stock-driver.sh

echo "============================================"
echo " Installing NVIDIA 610.43.02 (open module)"
echo "============================================"

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo:  sudo bash ~/610.sh"; exit 1; fi
if [ ! -f "$RUN" ]; then echo "Installer missing at $RUN"; exit 1; fi

echo "[1/5] Stopping the desktop + freeing the GPU..."
systemctl isolate multi-user.target
sleep 3
# Stop the NVIDIA user-space daemons that PIN the old modules (this caused the
# 'Device or resource busy' / version-mismatch failure last time).
systemctl stop nvidia-persistenced 2>/dev/null
systemctl stop nvidia-powerd 2>/dev/null
# Kill anything still holding a /dev/nvidia* handle, then unload the old stack.
fuser -k /dev/nvidia* 2>/dev/null
sleep 2
modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null
sleep 1
if lsmod | grep -q '^nvidia'; then
    echo "  WARNING: old nvidia modules still loaded — what is holding them:"
    lsmod | grep '^nvidia'
    fuser -v /dev/nvidia* 2>/dev/null
    echo "  Trying once more..."
    fuser -k /dev/nvidia* 2>/dev/null; sleep 2
    modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null; sleep 1
fi
if lsmod | grep -q '^nvidia'; then
    echo "!!! Could not unload old nvidia modules. Aborting BEFORE install (safe)."
    echo "!!! Reboot and retry, or tell Claude what 'fuser' showed above."
    exit 1
fi
echo "  old driver unloaded cleanly."

echo "[2/5] Removing the conflicting apt 595 driver (the duplicate-module cause)..."
# Verified safe via 'apt-get -s purge' simulation: removes ONLY the nvidia-595
# stack, NOT plasma-desktop / kernel / xserver-xorg-core.
apt-get purge -y 'nvidia-driver-595-open' 'libnvidia-*-595' 'linux-modules-nvidia-595-open-*' 'nvidia-utils-595' 'nvidia-compute-utils-595' 'xserver-xorg-video-nvidia-595'
# NOTE: deliberately NOT running 'apt autoremove' (it would try to take xserver-xorg-core).

echo "[3/5] Installing driver 610.43.02 (silent, open module)..."
sh "$RUN" --silent --kernel-module-type=open
RC=$?

if [ "$RC" -ne 0 ]; then
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo " INSTALL FAILED (exit $RC) -- NOT rebooting."
    echo " Restore your working driver with:"
    echo "     sudo bash $RECOVERY"
    echo " Then: sudo reboot"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit "$RC"
fi

echo "[4/5] Rebuilding initramfs..."
update-initramfs -u

echo "[5/5] SUCCESS. Rebooting in 10 seconds -- press Ctrl+C to cancel."
sleep 10
reboot
