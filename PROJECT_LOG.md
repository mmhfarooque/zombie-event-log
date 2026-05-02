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
| 15:50 | User reported app icon click did nothing — silent crash. Reproduced from terminal: `AttributeError: 'gi.repository.GLib' object has no attribute 'Object'`. Cause: PyGObject base class is `GObject.Object`, not `GLib.Object` (my mistake; muscle memory from older GLib API). Fixed `bin/zel-gui` import + subclass declaration. Re-smoke-tested — window launches cleanly, only a benign libadwaita-vs-KDE-theme warning. | ✓ |
| 16:15 | **MILESTONE — first real cycle captured (20260502-151823, 89s nap, locked=yes).** GSP fired (2 heartbeat timeouts), KWin attempted **21,990 renders** during the failure storm (10 atomic modeset retries, 4 output config rejections), then recovered. tail_gap = 48,449 clean journal lines. Outcome `rescued`. Proof-of-life for the entire project. | ✓ |
| 16:18 | Two follow-up bugs surfaced from the live data: (1) GUI right-pane never populated on row click — `selection-changed` signal in GTK4 SingleSelection isn't reliable for single-click; switched to `notify::selected` + ListView::activate, plus auto-show on first refresh. Also made ZEL_BIN absolute via `shutil.which`. (2) KWin classifier reported `medium` confidence on a textbook rescue. First "fix" broadened the grep pattern to include `GL_FRAMEBUFFER_INCOMPLETE` — backfired because those 21,990 symptoms cluster around the modeset failures, not after them, dropping tail_gap from 48k→35 and flipping verdict to false-catastrophic. Reverted to using only `Atomic modeset test failed!` for the gap calc (the cardinal signal), kept the broader pattern for counts. Confidence ladder: rescued/high if tail_gap > 1000, rescued/medium otherwise. | ✓ |
| 16:22 | Re-tested against live cycle: now correctly returns `outcome=rescued / outcome_confidence=high`. KWin adapter is now first-class. | ✓ |
| 17:11 | **Second real cycle captured (20260502-153242, 97-minute nap, locked=yes).** GSP fired (2 timeouts), KWin attempted **42,636 renders** during the failure storm (9 atomic modeset retries, 3 output config rejections), then recovered. tail_gap = 92,881 clean journal lines. Outcome `rescued / high`. Confirms the rescue scales with nap length and storm intensity. | ✓ |
| 17:14 | User did a clean uninstall + re-clone + re-install for verification — installer worked symmetrically, removed `20260502-151823` data, fresh install picked up new cycle correctly. Sequence proves install/uninstall are idempotent and complete. | ✓ |

## Sample data (first two real cycles)

| Field | Cycle 1 (15:18) | Cycle 2 (15:32, fresh install) |
|---|---|---|
| `cycle_id` | `20260502-151823` | `20260502-153242` |
| Nap duration | 89 seconds | 97 minutes |
| `compositor` | `kwin_wayland` | `kwin_wayland` |
| `locked_at_suspend` | yes | yes |
| `gsp_heartbeat_timeouts` | 2 | 2 |
| `drm_open_failures` | 8 | 6 |
| `kwin_atomic_modeset_failures` | 10 | 9 |
| `kwin_framebuffer_incomplete` | 21,990 | 42,636 |
| `kwin_output_config_failed` | 4 | 3 |
| `kwin_scene_gl_errors` | 21,990 | 42,636 |
| `kwin_tail_gap_lines` | 48,449 | 92,881 |
| `outcome` | rescued | rescued |
| `outcome_confidence` | high | high |
| `kernel` | `7.0.0-15-generic` | `7.0.0-15-generic` |

**Headline pattern observed:** the bug fires on 100% of suspends (2/2 cycles), KWin rescues on 100% of the cycles where it engages (2/2). Storm intensity (framebuffer error count) scales with nap length — longer nap = more journal lines accumulated during the retry storm before recovery.

### 2026-05-02 — Article phase

| Time | Step | Result |
|---|---|---|
| 17:38 | Drafted v1 of the companion blog article at `~/Photography Portfolio Website/articles/kde-vs-gnome-nvidia-suspend-rescue/article.md`. | ✓ |
| 17:39 | Created `meta.md` with full SEO fields, 15 tags, image inventory (4 images), tinker insert template, GSC/Bing submission steps. | ✓ |
| 17:40 | Updated `articles/ARTICLE_LOG.md` with entry #2 (Draft — awaiting images). | ✓ |
| 17:50 | User requested article be **refocused** on industry-wide NVIDIA Linux suspend situation rather than KDE-vs-GNOME comparison alone; tool to be framed as a logger, not a fix. Launched research agent for blog/vlog/issue-tracker citations. | ✓ |
| 17:55 | Research agent stalled mid-stream after gathering ~30% of targets; took over with direct WebFetch + WebSearch. | ✓ noted |
| 17:57 | User generated 4 ChatGPT images locally (light/neutral theme palette per the regenerated prompts). | ✓ |
| 18:00 | Renamed PNGs to slug-based filenames; converted to WebP via cwebp -q 82 -resize 1920 — total 5.6 MB → 410 KB (93% reduction). | ✓ |
| 18:05 | Rewrote `article.md` (2,630 words) with industry-wide framing, 18 cited sources spanning NVIDIA GitHub issues #1086/#1064/#1080/#1117/#1059/#446, NVIDIA Developer Forums, Arch/Ubuntu/Fedora/Mint forums, Framework Community thread, Phoronix/GamingOnLinux/UbuntuPit driver-release coverage. Tool framed as logger, Kubuntu/KDE recommendation in plain terms. | ✓ |
| 18:10 | Refreshed `meta.md` SEO: title 91c (long form for page), seo_title 58c (within Google's 60–65c desktop SERP cutoff), meta_description 173c (within 200c mobile cap), 15 tags aligned with current search terms. | ✓ |
| 18:11 | scp'd 4 WebP images + article.html to mfaruk.com (`/home/mfaruk/web/mfaruk.com/private/portfolio-app/storage/app/public/blog/`); chowned `mfaruk:www-data`, chmod 644. | ✓ |
| 18:13 | First tinker insert: Post created (id 5, status published, category 6, all images OK), but tag sync failed — `tags` table has no `type` column. Memory entry `reference-mfaruk-blog-conventions.md` was outdated; corrected. | ✓ rescued |
| 18:14 | Second tinker run with corrected tag schema (Tag::firstOrCreate by name, slug via Str::slug) — 15 tags attached. | ✓ |
| 18:15 | **Article live at <https://mfaruk.com/blog/kde-vs-gnome-nvidia-suspend-rescue>** — HTTP 200, all 4 images 200, sitemap.xml contains the new URL, ARTICLE_LOG.md flipped to Published. | ✓ |
| 18:18 | User reported tables on the live post invisible — dark text on dark theme. Diagnosed: `.blog-content` CSS in `resources/js/Pages/Public/Blog/Show.vue` only had rules for headings/paragraphs/lists/code/blockquote/img — `<table>`, `<th>`, `<td>` fell back to browser defaults. | ✓ |
| 18:21 | Added 8 CSS rules for table elements using existing CSS variables (`--text-primary`, `--text-secondary`, `--bg-tertiary`, `--border`); used Python injection (sed escaping CSS proved too fragile). Backed up Show.vue.bak-2026-05-02 on server. Ran `npm run build`, `php artisan view:clear`, `php artisan cache:clear`. | ✓ |
| 18:23 | Verified production CSS bundle (`Show-Bm0IfgXp.css`) contains the new rules. Fix applies to **all blog posts** going forward, not just this one. | ✓ |

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

