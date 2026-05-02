# Zombie Event Log — Project Log

**Project:** `zombie-event-log` (CLI binary: `zel`)
**Repo target:** `mmhfarooque/zombie-event-log` (GitHub, personal account `farooque7@gmail.com`)
**Local path:** `/home/mahmud/app-dev/zombie-event-log/`
**Started:** 2026-05-02
**Origin context:** spawned from the NVIDIA-GSP suspend/zombie investigation at `/home/mahmud/LinuxDev/nvidia-suspend-2026-04-30/`

## Why this exists

The NVIDIA-GSP investigation showed that KDE/KWin rescues the bug ~96% of the time on Mahmud's hardware where GNOME/mutter would never recover. Existing tools in `LinuxDev/nvidia-suspend-2026-04-30/` (`capture-resume-evidence.sh`, `scan-historical-suspends.sh`) only run on demand. This project packages the same idea as a passive, install-once telemetry tool that anyone on Linux can use to find out whether their compositor rescues their suspend bugs, and why.

Scope: **broad** — any suspend/resume telemetry, not NVIDIA-specific. NVIDIA GSP becomes the flagship example in `examples/`.

## Architecture (decided 2026-05-02)

- **Hook** (`/usr/lib/systemd/system-sleep/50-zel`): fires on every suspend/resume. Pre-suspend captures cycle_id, compositor, lock state, kernel, hostname → `cycles/<id>.json`. Post-resume appends `resume_at`. Exits fast — no classification inside the hook.
- **Lazy classification**: at query time, the CLI reads journal slices for that cycle and runs the classifier. Reason: avoids any wait-then-analyse complexity in the hook, and lets us re-classify if we improve the classifier.
- **Compositor adapters**: per-compositor signature parsers (kwin / mutter / muffin / xfwm). Pluggable.
- **Storage**: `/var/lib/zel/cycles/*.json` (system-wide because hook runs as root).
- **CLI**: `zel stats | last [N] | catastrophic | list | show <id> | compare <id1> <id2> | export <path> | doctor | version`.

## Steps log

### 2026-05-02 — Setup phase

| Time | Step | Result |
|---|---|---|
| 14:30 | Confirmed git identity routing: `~/app-dev/` defaults to `farooque7@gmail.com` per `~/.gitconfig`. Active `gh` account = `mmhfarooque`. | ✓ |
| 14:31 | Survey of `~/app-dev/`: existing pattern is parent meta-repo `mmhfarooque/app-dev` + nested per-project repos (e.g. `ibus-avro-fixed` → `mmhfarooque/ibus-avro-fixed`). | ✓ noted |
| 14:33 | Created folder skeleton: `bin/ hooks/ lib/adapters/ packaging/{debian,rpm,arch} docs/ examples/nvidia-gsp-bug-2026/ tests/`. | ✓ |
| 14:33 | Created PROJECT_LOG.md (this file). | ✓ |
| 14:33 | Wrote `.gitignore` (excludes /cycles/, build artifacts, editor noise). | ✓ |
| 14:35 | Wrote `hooks/50-zel` — pre/post phases, lock-state via loginctl, compositor via pgrep, sed-based JSON update so jq isn't required. | ✓ |
| 14:38 | Wrote `lib/core.sh` — subcommand dispatch, journal slicing, classification dispatcher; subcommands: stats, last, catastrophic, list, show, compare, export, doctor. | ✓ |
| 14:39 | Wrote `lib/adapters/kwin.sh` (first-class), `lib/adapters/mutter.sh` (partial stub), `lib/adapters/muffin.sh` (partial stub). | ✓ |
| 14:40 | Wrote `bin/zel` CLI entrypoint with system+dev lib path resolution. | ✓ |
| 14:41 | Wrote `install.sh`, `uninstall.sh` (with `--keep-data` flag). | ✓ |
| 14:42 | Wrote `LICENSE` (MIT), `README.md`. | ✓ |
| 14:44 | Wrote `docs/ARCHITECTURE.md`, `docs/SUPPORTED-DESKTOPS.md`, `docs/TROUBLESHOOTING.md`. | ✓ |
| 14:45 | **User instruction:** "always used latest and bleedingage technologies so it's futureproof". Saved as `feedback-bleeding-edge-tech.md` memory. Pivoted GUI plan from plain GTK4 to **GTK4 + libadwaita**, added Rust CLI rewrite as v1.0 roadmap, added Flatpak to distribution roadmap. Defended bash for the hook context (sub-ms start budget, minimal init env). | ✓ |
| 14:47 | Wrote `bin/zel-gui` (Python + GTK4 + libadwaita). Cycle list (left), detail pane (right), toolbar: Read Log / Copy Log / Copy All / Clear Logs (pkexec) / Doctor. ~310 LoC. | ✓ |
| 14:48 | Wrote `packaging/zel-gui.desktop` and patched `install.sh`/`uninstall.sh` to handle GUI conditionally (only if PyGObject + GTK4 + libadwaita are present). | ✓ |
| 14:49 | Wrote `examples/nvidia-gsp-bug-2026/README.md` referencing the LinuxDev investigation. | ✓ |
| 14:50 | Smoke test: `bash -n` on every shell file, `python3 -m py_compile bin/zel-gui` — all OK. | ✓ |
| 14:51 | Smoke test: hook exercised in pre/post mode against /tmp/zel-smoke; `zel last/stats/show/list/export/doctor` all pass; KWin adapter correctly classified the test cycle as `clean` with high confidence. | ✓ |
| 14:52 | Verified GTK4 (4.0) + libadwaita (1) both present on this machine — GUI is install-ready. | ✓ |
| 14:55 | `git init -b main`, identity verified (`farooque7@gmail.com`). Staged 18 files, removed accidentally-committed `bin/__pycache__/`, added `__pycache__/` and `*.pyc` to `.gitignore`. | ✓ |
| 14:56 | First commit: `v0.1.0 — initial scaffold` (5c79c7c, 1491 insertions). | ✓ |
| 14:58 | `gh repo create mmhfarooque/zombie-event-log --public --source=. --remote=origin --push` — repo live at <https://github.com/mmhfarooque/zombie-event-log>, MIT license auto-detected, default branch `main`. | ✓ |
| 15:30 | First user install (`mahmud@ms7e41`) clean — hook + CLI + GUI + desktop entry installed. Surfaced bug: missing icon → KDE menu shows generic doc icon. | ✓ noted |
| 15:32 | Designed flat SVG icon at `packaging/icons/net.farooque.ZombieEventLog.svg` — bold "Z" on slate gradient background with cyan heartbeat pulse along the bottom (sleep + monitoring metaphor). Updated `install.sh` to copy to `/usr/local/share/icons/hicolor/scalable/apps/`, refresh `gtk-update-icon-cache` and `kbuildsycoca6`. Updated `uninstall.sh` symmetrically. | ✓ |

## v0.1 file inventory

```
zombie-event-log/
├── PROJECT_LOG.md
├── README.md
├── LICENSE                                  (MIT)
├── .gitignore
├── install.sh                               (executable)
├── uninstall.sh                             (executable, --keep-data flag)
├── bin/
│   ├── zel                                  (bash CLI, executable)
│   └── zel-gui                              (GTK4 + libadwaita Python GUI, executable)
├── hooks/
│   └── 50-zel                               (systemd-sleep hook, executable)
├── lib/
│   ├── core.sh                              (sourced by bin/zel)
│   └── adapters/
│       ├── kwin.sh                          (first-class)
│       ├── mutter.sh                        (v0.1 partial)
│       └── muffin.sh                        (v0.1 partial)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SUPPORTED-DESKTOPS.md
│   └── TROUBLESHOOTING.md
├── examples/
│   └── nvidia-gsp-bug-2026/
│       └── README.md
├── packaging/
│   ├── zel-gui.desktop                      (XDG desktop entry)
│   ├── debian/                              (placeholder for v0.4)
│   ├── rpm/                                 (placeholder for v0.4)
│   └── arch/                                (placeholder for v0.4)
└── tests/                                   (placeholder)
```

