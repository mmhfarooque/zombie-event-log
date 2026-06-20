#!/usr/bin/env bash
# Register the running NVIDIA 610.43.02 (open) driver with DKMS so it auto-rebuilds
# on every future kernel update (no more black-screen-on-kernel-bump).
# Secure Boot stays OFF, so no signing needed.
# Run over SSH from the Mac (desktop will stop):  sudo bash ~/dkms-610.sh

RUN=/home/USER/DEV/nvidia-resume-fix/NVIDIA-Linux-x86_64-610.43.02.run
RECOVERY=/home/USER/DEV/nvidia-resume-fix/RECOVERY-restore-stock-driver.sh

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo:  sudo bash ~/dkms-610.sh"; exit 1; fi
if [ ! -f "$RUN" ]; then echo "Installer missing at $RUN"; exit 1; fi

echo "============================================"
echo " Registering NVIDIA 610.43.02 with DKMS"
echo "============================================"

echo "[1/5] Installing dkms..."
apt-get install -y dkms || { echo "dkms install failed (network?)"; exit 1; }

echo "[2/5] Stopping desktop + freeing the GPU..."
systemctl isolate multi-user.target
sleep 3
systemctl stop nvidia-persistenced 2>/dev/null
systemctl stop nvidia-powerd 2>/dev/null
fuser -k /dev/nvidia* 2>/dev/null
sleep 2
modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null
sleep 1
if lsmod | grep -q '^nvidia'; then
    echo "  WARN: nvidia still loaded; trying once more"; fuser -k /dev/nvidia* 2>/dev/null; sleep 2
    modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null
fi

echo "[3/5] Reinstalling 610 WITH dkms (open module)..."
sh "$RUN" --silent --dkms --kernel-module-type=open
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "!!! FAILED (exit $RC) -- NOT rebooting."
    echo "!!! Restore working driver: sudo bash $RECOVERY ; then sudo reboot"
    exit "$RC"
fi

echo "[4/5] DKMS status (should list nvidia 610.43.02 installed):"
dkms status

echo "[5/5] Rebuilding initramfs. Rebooting in 10s -- Ctrl+C to cancel."
update-initramfs -u
sleep 10
reboot
