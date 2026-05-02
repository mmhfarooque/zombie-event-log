#!/bin/bash
# zel installer — copies hook, CLI, and library into system locations.
# Run as root: sudo bash install.sh

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "install.sh: must be run as root (try: sudo bash install.sh)" >&2
    exit 1
fi

SRC_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
HOOK_DST=/usr/lib/systemd/system-sleep/50-zel
BIN_DST=/usr/local/bin/zel
GUI_DST=/usr/local/bin/zel-gui
LIB_DST=/usr/local/share/zel/lib
DATA_DST=/var/lib/zel/cycles
DESKTOP_DST=/usr/local/share/applications/zel-gui.desktop

echo "zel — installing from $SRC_DIR"

# Dependencies
missing=()
for cmd in journalctl loginctl pgrep date; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "  ! missing required commands: ${missing[*]}"
    echo "    install them first (typically via systemd, util-linux, procps)"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "  ! jq not found — recommended but not required (CLI falls back to grep parsing)"
fi

# Hook
install -m 0755 "$SRC_DIR/hooks/50-zel" "$HOOK_DST"
echo "  + $HOOK_DST"

# CLI
install -m 0755 "$SRC_DIR/bin/zel" "$BIN_DST"
echo "  + $BIN_DST"

# GUI (optional — only installed if PyGObject + GTK4 + libadwaita are available)
if python3 -c "import gi; gi.require_version('Gtk','4.0'); gi.require_version('Adw','1'); from gi.repository import Gtk, Adw" >/dev/null 2>&1; then
    install -m 0755 "$SRC_DIR/bin/zel-gui" "$GUI_DST"
    install -d -m 0755 /usr/local/share/applications
    install -m 0644 "$SRC_DIR/packaging/zel-gui.desktop" "$DESKTOP_DST"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/local/share/applications 2>/dev/null || true
    fi
    echo "  + $GUI_DST + desktop entry"
else
    echo "  - skipping zel-gui (install python3-gi + gir1.2-gtk-4.0 + gir1.2-adw-1 to enable)"
fi

# Library
mkdir -p "$LIB_DST/adapters"
install -m 0644 "$SRC_DIR/lib/core.sh" "$LIB_DST/core.sh"
install -m 0644 "$SRC_DIR/lib/adapters/kwin.sh"   "$LIB_DST/adapters/kwin.sh"
install -m 0644 "$SRC_DIR/lib/adapters/mutter.sh" "$LIB_DST/adapters/mutter.sh"
install -m 0644 "$SRC_DIR/lib/adapters/muffin.sh" "$LIB_DST/adapters/muffin.sh"
echo "  + $LIB_DST/{core.sh,adapters/*}"

# Data dir
mkdir -p "$DATA_DST"
chmod 0755 /var/lib/zel "$DATA_DST"
echo "  + $DATA_DST"

echo
echo "zel installed. Try: zel doctor"
echo "Cycles will be recorded automatically on the next suspend."
