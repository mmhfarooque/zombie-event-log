#!/bin/bash
# zel uninstaller — removes hook, CLI, and library. Pass --keep-data to preserve cycles/.
# Run as root: sudo bash uninstall.sh [--keep-data]

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "uninstall.sh: must be run as root (try: sudo bash uninstall.sh)" >&2
    exit 1
fi

KEEP_DATA=0
[ "${1:-}" = "--keep-data" ] && KEEP_DATA=1

echo "zel — uninstalling"

rm -fv /usr/lib/systemd/system-sleep/50-zel
rm -fv /usr/local/bin/zel
rm -fv /usr/local/bin/zel-gui
rm -fv /usr/local/share/applications/zel-gui.desktop
rm -rfv /usr/local/share/zel
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/local/share/applications 2>/dev/null || true
fi

if [ "$KEEP_DATA" -eq 1 ]; then
    echo "  · keeping data dir at /var/lib/zel (--keep-data passed)"
else
    rm -rfv /var/lib/zel
fi

echo
echo "zel uninstalled."
