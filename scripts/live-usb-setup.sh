#!/bin/bash
# scripts/live-usb-setup.sh
#
# One-shot bootstrap for the mutter zombie-cycle experiment on a Ubuntu
# Desktop Live USB.  See docs/EXPERIMENT-MUTTER-LIVE-USB.md for the full
# procedure, including the post-bootstrap steps (SSH from laptop, trigger
# suspend, capture).
#
# Usage:
#   git clone https://github.com/mmhfarooque/zombie-event-log.git
#   cd zombie-event-log
#   sudo bash scripts/live-usb-setup.sh
#
# Or as a one-liner (idempotent — safe to re-run):
#   curl -sSL https://raw.githubusercontent.com/mmhfarooque/zombie-event-log/main/scripts/live-usb-setup.sh | sudo bash
#
# What it does:
#   1. apt update + install git, jq, openssh-server, python3-gi (GUI deps usually present on GNOME)
#   2. ubuntu-drivers autoinstall (idempotent — installs NVIDIA driver if available)
#   3. modprobe nvidia (try without restarting gdm)
#   4. clone zombie-event-log if not already in cwd
#   5. sudo bash install.sh
#   6. enable + start ssh (so laptop can SSH in for the capture)
#   7. set ubuntu password if unset, print LAN IP
#   8. zel doctor to confirm the install
#
# Designed for Ubuntu 26.04 Desktop Live (GNOME). Should work on derivatives.
# Idempotent: every step skips work it has already done.

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "live-usb-setup.sh: must be run as root" >&2
    echo "  try: sudo bash scripts/live-usb-setup.sh" >&2
    exit 1
fi

log() { printf '\n=== %s ===\n' "$*"; }
warn() { printf '\n!!  %s\n' "$*" >&2; }

REPO_URL="https://github.com/mmhfarooque/zombie-event-log.git"
SRC_DIR=""
if [ -f "$(pwd)/install.sh" ] && [ -d "$(pwd)/lib/adapters" ]; then
    SRC_DIR="$(pwd)"
fi

# 1. apt update + dependencies ------------------------------------------------
log "Installing dependencies (git, jq, ssh, python GTK4 bindings)"
DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git jq openssh-server \
    python3-gi gir1.2-gtk-4.0 gir1.2-adw-1

# 2. NVIDIA driver ------------------------------------------------------------
log "Installing NVIDIA proprietary/open driver via ubuntu-drivers"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    echo "  + already loaded:"
    nvidia-smi | head -3
else
    if command -v ubuntu-drivers >/dev/null 2>&1; then
        ubuntu-drivers autoinstall || warn "ubuntu-drivers autoinstall returned non-zero — continuing anyway"
    else
        warn "ubuntu-drivers not present; skipping. You may need to install nvidia-driver-XXX-open manually."
    fi
    # Try to load without rebooting / restarting display manager
    if modprobe nvidia 2>/dev/null; then
        nvidia-smi | head -3 || true
    else
        warn "modprobe nvidia failed (X may have nouveau pinned). The driver is installed; reload via: sudo systemctl restart gdm"
    fi
fi

# 3. Clone or use existing checkout ------------------------------------------
if [ -z "$SRC_DIR" ]; then
    log "Cloning $REPO_URL"
    cd /root || cd /tmp
    if [ ! -d zombie-event-log ]; then
        git clone "$REPO_URL"
    else
        ( cd zombie-event-log && git pull --ff-only )
    fi
    SRC_DIR="$(pwd)/zombie-event-log"
fi

# 4. Install zel --------------------------------------------------------------
log "Installing zel (hook + CLI + GUI + lib)"
( cd "$SRC_DIR" && bash install.sh )

# 5. SSH ----------------------------------------------------------------------
log "Configuring SSH for remote capture from laptop"
systemctl enable --now ssh

# Set ubuntu password if it isn't already set (live ISO ships passwordless)
if [ -n "${ZEL_LIVE_USB_PASSWORD:-}" ]; then
    echo "ubuntu:${ZEL_LIVE_USB_PASSWORD}" | chpasswd
    echo "  + set ubuntu password from \$ZEL_LIVE_USB_PASSWORD"
else
    if ! passwd -S ubuntu 2>/dev/null | awk '{print $2}' | grep -q '^P$'; then
        echo "  ! ubuntu password not set — run: sudo passwd ubuntu"
    fi
fi

# 6. Print LAN IPs + next-step hint ------------------------------------------
log "LAN IPs (use one of these for SSH from your laptop):"
hostname -I 2>/dev/null || ip -4 addr | awk '/inet / && $NF != "lo" {print "  " $2 "  on  " $NF}'

echo
log "zel doctor"
zel doctor || true

cat <<'EOF'

================================================================
zel is installed and the system is prepared for the experiment.

Next steps (see docs/EXPERIMENT-MUTTER-LIVE-USB.md for full detail):

  1. From your laptop, SSH in:
        ssh ubuntu@<one of the IPs printed above>

  2. In the SSH session, start a streaming journal capture:
        sudo journalctl -f -k > /tmp/cycle-journal.log &

  3. From this terminal (live USB), trigger a long suspend:
        sleep 5 && systemctl suspend

  4. Wait at least 5 minutes, then wake the box (mouse / keyboard).
     Watch the screen — does GNOME recover, or does mutter zombie?

  5. From the laptop SSH session, capture the result:
        zel last 5
        sudo cp -a /var/lib/zel/cycles /tmp/mutter-evidence/

  6. Exfiltrate to NAS or GitHub gist before powering off — this is
     a live USB, no persistence: everything in RAM is lost on power.
================================================================
EOF
