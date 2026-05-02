# Supported desktops

| Compositor | Detection | Adapter | Outcome confidence | Notes |
|---|---|---|---|---|
| `kwin_wayland` | ✓ | ✓ first-class | High | Validated against real GSP-zombie events on KDE Plasma 6.6.4 + NVIDIA 595.58.03-open. |
| `kwin_x11` | ✓ | ✓ first-class | High | Same signal model as Wayland in practice. |
| `gnome-shell` (mutter) | ✓ | ⚠ partial | Low | Needs ground-truth journals from real GNOME zombie events. Today, any KMS/page-flip error is treated as catastrophic — there's no rescue model yet. |
| `cinnamon` (muffin) | ✓ | ⚠ partial | Low | Mutter fork; signals are similar but log namespace differs. Needs Mint zombie journals. |
| `xfwm4` (XFCE) | ✓ | ✗ | — | Detection only. XFCE has very different KMS handling. |
| `sway` | ✓ | ✗ | — | Detection only. Wayland-only; will need wlroots-specific signals. |
| `hyprland` | ✓ | ✗ | — | Detection only. |

## How to contribute an adapter

1. Capture a real zombie or near-zombie cycle on the target compositor:
   ```bash
   sudo bash install.sh
   # induce a suspend/resume that you know fails or near-fails
   zel show <cycle_id>
   journalctl --since "<suspend_at>" --until "<resume_at>+5min" > zombie-evidence.txt
   ```
2. Open an issue with `zombie-evidence.txt` attached.
3. Or, write the adapter directly: copy `lib/adapters/mutter.sh` as a starting template, replace the grep patterns with the signals you found, and submit a PR.

## Adapter signal model

Each adapter answers four questions from the journal slice:

1. **Did the compositor try to render against a broken DRM/KMS state?** — count of KMS/page-flip errors.
2. **How many retries did it make?** — repetition count.
3. **Did the retries succeed?** — gap between the last failure and the slice tail.
4. **Or did it fail terminally?** — failures continuing into the slice tail.

KWin emits very loud, very repetitive failure logs (`Atomic modeset test failed!` × 20+) which makes signal extraction easy. mutter is quieter, which is why its adapter is harder to make confident.
