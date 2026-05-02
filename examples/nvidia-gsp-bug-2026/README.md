# Example — NVIDIA GSP suspend bug, May 2026

This is the case `zel` was originally built to measure.

## The bug

NVIDIA's `nvidia-driver-595-open` 595.58.03 (the open kernel module) fails the GSP firmware-handshake on every resume from suspend on Ampere+ hardware. Kernel logs show:

```
NVRM: _kgspIsHeartbeatTimedOut: Heartbeat timed out, ... timeout 5200
NVRM: _kgspRpcRecvPoll: GSP RM heartbeat timed out
```

After this, the DRM device becomes unavailable. Whether the user *experiences* a zombie wake depends entirely on the compositor.

## What `zel stats` shows on the affected machine

```
Zombie Event Log — summary

  total cycles:        27
  clean (no GSP/error): 0
  rescued by compositor: 26
  catastrophic:        1
  unclassified:        0
  cycles with GSP:     27
  rescue rate:         96% (26 of 27 non-clean cycles)
```

The bug fires on **100%** of suspend cycles. KWin recovers from **96%** via aggressive atomic-modeset retries combined with the natural 10-30 second delay introduced by KDE's screen-locker / PAM-unlock pathway. The 4% catastrophic rate are the cases the user actually feels — black screen, hard power-cycle required.

## Why GNOME users see this differently

mutter (GNOME Shell) doesn't have KWin's retry-then-succeed pattern. When mutter sees a broken DRM context post-resume, it tends to give up. The same hardware, same driver, same kernel — but with mutter, the rescue rate plummets, and the user sees zombies on every suspend.

This is the kind of difference `zel` is designed to surface and quantify on your own machine.

## The actual fix (upstream)

NVIDIA released `nvidia-driver-595-open` 595.71.05 on 2026-04-28 with release notes describing exactly this Wayland resume restoration fix. As of 2026-05-02, it had not yet landed in Ubuntu's `resolute/restricted`, `resolute-updates`, `-proposed`, or the `graphics-drivers` PPA — only in NVIDIA's official `cuda` repo.

When 595.71.05 lands in Ubuntu repos, `zel stats` should drop to `gsp_heartbeat_timeouts=0` on every cycle.

## Source investigation

The full investigation that led to building `zel` lives at `/home/mahmud/LinuxDev/nvidia-suspend-2026-04-30/` on the developer's machine. See particularly:

- `2026-05-01-nvidia-suspend-zombie.md` — the full investigation log
- `historical-suspend-scan-20260501-185155.txt` — raw evidence supporting the 100%/96% numbers
- `resume-evidence-20260501-145127-7.0.0-15-generic.txt` — first GSP smoking gun on kernel `7.0.0-15`
- `resume-evidence-20260501-172152-7.0.0-14-generic.txt` — confirmation that `-14` exhibits the same bug (kernel ruled out as cause)
