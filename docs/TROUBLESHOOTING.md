# Troubleshooting

## `zel doctor` says the hook is not installed

Re-run the installer:
```bash
sudo bash install.sh
```

## `zel last` says "no cycles recorded yet"

The hook only fires on actual suspend/resume cycles. After install, you need to suspend and resume your machine at least once before any cycles appear. To force one for testing:

```bash
sudo systemctl suspend
# wake the machine, then:
zel last
```

## Cycles missing `resume_at`

If a cycle has `suspend_at` set but `resume_at: null`, the resume path didn't fire. Possible causes:
- Hard power-cycle from a catastrophic zombie wake (the most useful signal — these *are* the events you care about)
- Hibernate-from-suspend that crossed a reboot
- The hook was uninstalled mid-cycle

Cycles with this pattern should be inspected with `zel show <id>` and the kernel log examined manually.

## `outcome=unknown_compositor`

Your compositor was detected but has no adapter yet (XFCE, Sway, Hyprland, etc.). The capture data is still preserved — you can re-run `zel stats` later if an adapter is added in a future release. To contribute one yourself, see `docs/SUPPORTED-DESKTOPS.md`.

## "Permission denied" reading `/var/lib/zel/cycles/`

The data dir is `0755`, files are `0644`, so any user should be able to read. If you're hitting permission denied, check:

```bash
ls -la /var/lib/zel/
ls -la /var/lib/zel/cycles/ | head
```

If the perms are wrong, fix with:
```bash
sudo chmod 0755 /var/lib/zel /var/lib/zel/cycles
sudo chmod 0644 /var/lib/zel/cycles/*.json
```

## `jq: command not found`

Optional. The CLI falls back to grep parsing if jq is missing. Install for cleaner JSON handling:
- Debian/Ubuntu/Mint: `sudo apt install jq`
- Fedora: `sudo dnf install jq`
- Arch: `sudo pacman -S jq`

## Stopping zel from recording

```bash
sudo bash uninstall.sh             # removes everything including data
sudo bash uninstall.sh --keep-data # removes hook+CLI but keeps cycles/
```

Or, to pause without uninstalling:
```bash
sudo chmod -x /usr/lib/systemd/system-sleep/50-zel
```
And re-enable later with `chmod +x`.
