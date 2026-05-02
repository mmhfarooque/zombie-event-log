# Architecture

## Design goals

1. **Zero idle cost.** No long-running daemon. The hook only fires on actual suspend/resume events.
2. **One-time install, no maintenance.** `bash install.sh` and forget. Cycles accumulate; queries work whenever you want them.
3. **Compositor-agnostic capture, compositor-specific classification.** Capture is universal (cycle metadata + journal). Classification is plugged per-compositor.
4. **Lazy classification.** Classification is performed at *query* time, not capture time. This means:
   - The hook is trivial and can't slow down suspend/resume.
   - Improving an adapter retroactively re-classifies historical data.
5. **Cross-distro by construction.** Anything systemd-based (Ubuntu/Mint/Fedora/Arch/Debian) works without per-distro forks.

## Components

```
                             ┌────────────────────┐
   suspend/resume signal ──▶ │ /usr/lib/systemd/  │
                             │ system-sleep/      │
                             │   50-zel           │  (hook)
                             └─────────┬──────────┘
                                       │ writes
                                       ▼
                             ┌────────────────────┐
                             │ /var/lib/zel/      │
                             │   cycles/          │  (per-cycle JSON)
                             │   <id>.json        │
                             └─────────┬──────────┘
                                       │ read
                                       ▼
                             ┌────────────────────┐         ┌─────────────────┐
                             │ /usr/local/bin/zel │◀──────▶│ journalctl       │
                             │  (CLI)             │   pulls │ slice for cycle  │
                             └─────────┬──────────┘         └─────────────────┘
                                       │ dispatches
                                       ▼
                             ┌────────────────────┐
                             │ /usr/local/share/  │
                             │   zel/lib/         │
                             │     core.sh        │
                             │     adapters/      │
                             │       kwin.sh      │
                             │       mutter.sh    │
                             │       muffin.sh    │
                             └────────────────────┘
```

## Cycle JSON schema (v1)

```json
{
  "cycle_id": "20260502-145503",
  "schema_version": 1,
  "event_type": "suspend",
  "suspend_at": "2026-05-02T14:55:03+10:00",
  "suspend_at_epoch": 1777777503,
  "resume_at": "2026-05-02T15:18:42+10:00",
  "resume_at_epoch": 1777778922,
  "compositor": "kwin_wayland",
  "locked_at_suspend": "yes",
  "kernel": "7.0.0-15-generic",
  "hostname": "ms7e41",
  "note": null
}
```

`note` is set to `"resume_without_pre"` when a resume fires without a matching pre-suspend record (rare; happens if zel is installed mid-cycle, or hibernate-then-resume crosses a reboot).

## Classifier outcomes

| Outcome | Meaning |
|---|---|
| `clean` | No driver/compositor errors observed in the journal slice. |
| `rescued` | Errors observed, but the compositor recovered before the slice tail. |
| `catastrophic` | Errors observed and ongoing into the slice tail — the compositor did not recover. |
| `unknown_compositor` | The compositor at suspend time has no adapter yet. Capture data is preserved for later analysis. |

Each outcome carries a confidence (`high`, `medium`, `low`) so heuristic results don't masquerade as ground truth.

## Adapter contract

An adapter is a shell function that takes one argument — the journal slice text — and writes `key=value` lines to stdout.

Required keys:
- `outcome=<clean|rescued|catastrophic>`
- `outcome_confidence=<high|medium|low>`

Optional keys: any compositor-specific signal worth surfacing (modeset retry counts, KMS error codes, etc.).

See `lib/adapters/kwin.sh` for the reference implementation.

## Why bash, not Python (for the core)?

- Hook runs in systemd-sleep context with minimal environment. Bash + coreutils + journalctl are guaranteed to be present on every systemd distro.
- No Python interpreter cold-start in the hook path.
- The CLI is also bash to keep dependency surface single-language.
- The optional GUI (`zel-gui`) is GTK4 + Python — that's a *separate* tool, not the core.
