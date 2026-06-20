# Zombie Event Log — Project Log

**Project:** `zombie-event-log` (CLI binary: `zel`)
**Repo target:** `mmhfarooque/zombie-event-log` (GitHub, personal account `farooque7@gmail.com`)
**Local path:** `/home/USER/app-dev/zombie-event-log/`
**Started:** 2026-05-02
**Origin context:** spawned from the NVIDIA-GSP suspend/zombie investigation at `/home/USER/LinuxDev/nvidia-suspend-2026-04-30/`

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
| 18:11 | scp'd 4 WebP images + article.html to mfaruk.com (`<app-dir>/storage/app/public/blog/`); chowned `mfaruk:www-data`, chmod 644. | ✓ |
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

### 2026-05-03 — Third real cycle + classifier-window discovery

| Time | Step | Result |
|---|---|---|
| 14:00 | **Third real cycle captured (`20260503-135828`, 109s nap, locked=yes).** GSP fired (2 timeouts), KWin retried 3 atomic modesets, 0 framebuffer-incomplete, 4 drm-open failures, tail_gap=256. Outcome `rescued / medium` — confidence dropped from "high" because the post-storm tail gap fell below the 1000-line threshold (busy machine post-resume). | ✓ |
| 14:30 | User asked whether `kwin_framebuffer_incomplete` and `kwin_scene_gl_errors` returning identical counts (42,636 = 42,636 in C2) indicated double-counting. Verified directly: ran both regexes against the journal — counts equal but `BOTH-on-same-line = 0`. Confirmed they're **separate log entries** that fire in lockstep (1:1 per failed render), not a double-count bug. KWin emits two journal records per broken frame: one for `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT` from the FB stage, one for `kwin_scene_opengl GL_INVALID_OPERATION` from the scene loop. Classifier counts are correct; they describe the same underlying event from two angles. | ✓ |
| 14:35 | **Discovered classifier slice undercounts catastrophic cycles.** `zel_journal_slice()` ends at `resume_at + 120s grace`. C2 storm extended **~19 minutes** past resume — the captured 42,636 events represent only the first 2 minutes; the next 17 minutes (17:12:37 → ~17:30) added another **19,122** framebuffer events, completely outside the classifier's window. Total real storm: 61,758 events sustained over ~19 minutes (~52 events/sec). The slice cuts off ~31% of catastrophic-cycle severity. Outcome verdict was still correct (rescued), but severity is under-reported. | ✓ |

## Three-cycle comparison (as of 2026-05-03)

| Field | C1 `20260502-151823` | **C2 `20260502-153242`** | C3 `20260503-135828` |
|---|---|---|---|
| Nap duration | 89s | **5,875s (98 min)** | 109s |
| `gsp_heartbeat_timeouts` | 2 | **2** | 2 |
| `drm_open_failures` | 8 | **6** | 4 |
| `kwin_atomic_modeset_failures` | 10 | **9** | 3 |
| `kwin_framebuffer_incomplete` | 21,990 | **42,636** *(+19,122 outside slice = 61,758 real)* | 0 |
| `kwin_output_config_failed` | 4 | **3** | 0 |
| `kwin_scene_gl_errors` | 21,990 | **42,636** *(+19,122 outside slice = 61,758 real)* | 0 |
| `kwin_tail_gap_lines` | 48,449 | 92,881 | 256 |
| `outcome` | rescued | **rescued** | rescued |
| `outcome_confidence` | high | **high** | medium |

**Refined headline:** GSP timeouts = constant (2 / 2 / 2 across all three) — bug is duration-independent. Storm severity scales with nap length: short naps (89s, 109s) → minor render storms; long nap (98 min) → 19-minute catastrophic render storm with 61k+ failed frames. **KWin rescued all three.** C2 is the hero data point for the article — show this one to demonstrate KWin's atomic-modeset retry loop surviving ~52 frame failures per second sustained over ~19 minutes.

## Improvement targets identified (post-three-cycle review)

These are concrete v0.2 fixes prompted by the three-cycle dataset, prioritised:

1. **Adaptive journal slice** *(high priority — blocks accurate severity reporting on catastrophic cycles)*. Current `zel_journal_slice()` ends at `resume + 120s`. Should grow until the journal goes silent for N consecutive seconds (e.g. 30s of no compositor errors) or hard-cap at resume + 30 min. Persist `slice_end_epoch` into the cycle JSON so subsequent reads are reproducible.
2. **Persist classifier output at capture time** *(high priority — journal rotation will erode old cycles)*. Today the classifier runs on demand against the live journal; once journal slices age out / vmcore rotates, old cycles become unverifiable. Write `<cycle_id>.classifier.json` alongside the metadata file at first read, then re-use it. Cycle JSON also gains a `classifier_run_at` field.
3. **`storm_duration_seconds` derived signal**. First-failure-line-timestamp to last-failure-line-timestamp. More user-facing than raw counts; "19-minute render storm" reads better than "42,636 events". Pairs naturally with `nap_duration_seconds`.
4. **`render_recovery_at` timestamp**. Timestamp of the last failure line + N silent seconds. Lets a user say "screen actually became usable at HH:MM:SS, N minutes after resume". Different from `resume_at` (kernel wake) and from `tail_gap` (line-based proxy).
5. **`severity` bucket**. Derived: `mild` (< 1k render failures), `moderate` (1k–10k), `severe` (> 10k). Articles, GUI, and `zel stats` can summarise without exposing raw counts.
6. **`gpu_render_failures` rollup**. KWin emits framebuffer + scene_gl pair per failed frame; expose `gpu_render_failures = max(framebuffer_incomplete, scene_gl_errors)` as the canonical count, keep the two raw signals for diagnostic detail. Mutter/muffin adapters get the same field name when implemented.
7. **GSP recovery detector** *(NVIDIA-specific signal)*. Match `nvidia_gsp_recovery_at` from log lines indicating GSP came back ("nvidia: GPU resumed", "GSP RM IFR Boot completed", or similar). Brackets the bug duration precisely; useful for the example/article.
8. **Classifier confidence: drop the `tail_gap > 1000` absolute floor in favour of a relative one**. C3 had only 256 clean lines after the storm because the system was busy post-resume — that's a clean rescue but the verdict said `medium`. Should use `tail_gap > N% of slice` only, with `N` calibrated against the three-cycle dataset.
9. **Hook capture: store the systemd-sleep `event_type` distinction**. Currently always written as `suspend`; should reflect whether the trigger was suspend, hibernate, or hybrid-sleep so cross-event analysis works.
10. **GUI: severity colour-coding in the cycle list**. With `severity` field landed, the left-pane list gets red/orange/green dots — at-a-glance triage.

### Quick wins (can ship as v0.1.1 patches)
- Items #6 (rollup field), #8 (confidence threshold), #9 (event_type) — small, no schema changes downstream.

### Schema-changing (need v0.2 cut)
- Items #1, #2, #3, #4, #5, #7 — touch the cycle JSON schema (bump `schema_version` to 2). Migration path: classifier reads schema_version and re-runs against journal for v1 cycles, fills in missing fields if journal still has the slice; otherwise marks fields `null` with `note=schema_v1_legacy`.

### 2026-05-03 — v0.2 build session ("nothing to do this Sunday")

User instruction: do all 10 v0.2 improvement items in one session.

| Time | Step | Result |
|---|---|---|
| 16:00 | Fourth real cycle captured mid-build (`20260503-142615`) — 1h35m nap, GSP=2, drm_open=8 (highest yet), kwin_atomic_modeset=6, only 24 framebuffer events, storm_duration=0s. Rescued/high. New record for least-disruptive long nap. Captured fortuitously while we were rewriting the classifier — perfect end-to-end smoke. | ✓ |
| 16:05 | **Item #9 done** — `hooks/50-zel` schema_version bumped 1→2 in both pre and post paths. Confirmed `event_type` was already correctly captured from systemd-sleep `$2`. | ✓ |
| 16:15 | **Items #1, #2, #3, #4, #5, #7 — major core.sh rewrite (v0.2.0).** New constants `ZEL_SLICE_HARD_CAP_SECONDS=1800`, `ZEL_SLICE_SILENCE_SECONDS=30`, `ZEL_SLICE_INITIAL_GRACE=60`, `ZEL_SEVERITY_*_MIN`. `zel_journal_slice()` now pulls a wide 30-min window post-resume; storm end is derived from the data. New helpers `zel_journal_first_ts/last_ts`, `zel_severity_bucket`, `zel_classifier_file`, `zel_classify_persist`, `zel_classify_cached`, `zel_reclassify`. New signals emitted: `nvidia_gsp_first_timeout_at`, `nvidia_gsp_recovery_at`, `nvidia_gsp_wedge_seconds`, `gpu_render_failures`, `severity`, `storm_duration_seconds`, `render_recovery_at[_epoch]`, `storm_silence_seconds`, `slice_end_epoch`, `classifier_run_at[_epoch]`. | ✓ |
| 16:18 | **Item #6 — `gpu_render_failures` rollup** added universally as `max(framebuffer_incomplete, scene_gl_errors)`. KWin emits both 1:1 paired per failed frame; max() is the right canonical count. Raw signals retained for diagnostics. | ✓ |
| 16:20 | **Item #8 — confidence threshold rewritten universally.** Adapters now emit raw counts + first/last failure timestamps only; outcome/confidence is derived in `core.sh` from `storm_silence_seconds`. New rules: clean if zero errors, rescued/high if silence ≥ 60s, rescued/medium if 30–60s, catastrophic otherwise (high if silence < 5s, medium otherwise). Drops the v0.1 `tail_gap > 1000` absolute floor that misclassified C3's busy post-resume as `medium`. | ✓ |
| 16:22 | KWin / mutter / muffin adapters refactored to v0.2 contract — emit `<compositor>_first_failure_at` / `<compositor>_last_failure_at` (raw "May DD HH:MM:SS" strings, parsable via `date -d`); kwin_tail_gap_lines kept as a diagnostic but no longer used for outcome. | ✓ |
| 16:24 | Added `zel reclassify <id>` subcommand and registered it in `bin/zel`. | ✓ |
| 16:26 | Fixed `bin/zel` ZEL_LIB_DIR resolver — was preferring system install over dev tree, blocking dev iteration. Now: env override > dev sibling > /usr/local > /usr/share. | ✓ |
| 16:28 | First smoke against C2 (hero cycle) revealed PermissionDenied on `/var/lib/zel/cycles/<id>.classifier.json` — directory is root-owned (hook writes as root); CLI runs as user. | ✓ noted |
| 16:30 | **Item #2 — moved classifier cache to `XDG_CACHE_HOME/zel/classifier/`** (per-user). `zel_classifier_file()` now mkdir's and returns under XDG cache. Per-user cache is fine because classifier output is reproducible from the journal. | ✓ |
| 16:33 | **Re-smoke against all three cycles (C1=`20260502-153242`, C2=`20260503-135828`, C3=`20260503-142615`):** all clean. `zel show`, `zel last`, `zel stats`, `zel reclassify` all work. **Stats: 3 total, 3 rescued (100% rescue rate), 1 severe + 2 mild, 3/3 GSP firings.** | ✓ |
| 16:36 | **Discovery from new wider slice on C1:** the v0.1 fixed window captured 42,636 framebuffer events; the v0.2 wide slice captures the FULL **61,758** (the 19,122 events that fell outside v0.1's `resume + 120s` window are now counted). Storm duration corrected: it's actually a **~3-minute** storm (172s), not the 19 minutes I'd estimated from the wider 17:30 cut-off — the storm ended at 17:13:30, after which the journal went silent. Hero cycle is even more impressive: ~344 frame failures per second sustained for 3 minutes, KWin recovered to a usable desktop. | ✓ insight |
| 16:38 | Universal nvidia_gsp_wedge_seconds = 1 across all 3 cycles. Kernel re-inits GPU in 1 second; what we previously called "long zombie storm" is the COMPOSITOR's reconciliation time, not GPU wedge time. Two-stage recovery model now visible: kernel-level (GSP, ~1s) and compositor-level (KWin, 0–172s). | ✓ insight |
| 16:42 | **Item #10 — GUI severity dots in `bin/zel-gui`.** Red / orange / green Pango-markup bullets keyed off the severity field. Footer summary line: "N cycles · X% rescue · severe N · moderate N · mild N". Bumped APP_VERSION to 0.2.0. Added per-user cache support and stale-cache cleanup on Clear-Logs. List rows pre-populated from cache (no journalctl per row). Smoke test: `python3 -m py_compile` clean; `timeout 4 ./bin/zel-gui` opens window without traceback. | ✓ |
| 16:45 | uninstall.sh: added a notice that per-user XDG caches at `~/.cache/zel/` aren't removed (root can't safely touch user homes); each user can run `rm -rf ~/.cache/zel`. | ✓ |
| 16:48 | README.md: new "What's new in v0.2" section, classifier cache row in components table, `zel reclassify` documented, roadmap entry flipped to "done". | ✓ |
| 16:50 | Final smoke: all shell + python files syntax-clean, `zel version` shows `0.2.0`, `zel last`/`stats` show severity column + summary, `zel reclassify` overwrites cache cleanly. | ✓ |

### v0.2 schema (cycle.json) — additions over v0.1

```diff
  "schema_version": 1   →   "schema_version": 2
```

(Cycle JSON keeps the same metadata fields. New fields live in the **classifier output** which is now persisted separately at `~/.cache/zel/classifier/<id>.classifier.json` rather than mixed into cycle.json. Keeps the hook trivial and the metadata stable.)

### v0.2 classifier output — full field inventory

```
schema_version, compositor, slice_end_epoch
gsp_heartbeat_timeouts, drm_open_failures
nvidia_gsp_first_timeout_at[_epoch], nvidia_gsp_recovery_at[_epoch], nvidia_gsp_wedge_seconds
<compositor>_* raw counts (e.g. kwin_atomic_modeset_failures, kwin_framebuffer_incomplete, ...)
<compositor>_first_failure_at, <compositor>_last_failure_at
gpu_render_failures, severity
storm_duration_seconds, render_recovery_at[_epoch], storm_silence_seconds
outcome, outcome_confidence
classifier_run_at[_epoch]
```

### Migration: v1 cycle JSONs

v1 cycle.json files (the three captured 2026-05-02 / 2026-05-03 with `schema_version: 1`) work unmodified — `zel show` re-runs the classifier and writes a v2 classifier.json into the cache. Field availability depends on whether the journal still has the slice (systemd journals rotate on disk pressure or `journalctl --vacuum-time`). Old v1 cycles continue to be classifiable as long as their journal slice is reachable.

### 2026-05-03 evening — mutter live-USB experiment plan (next session)

After v0.2.0 ship, scoped the next experiment: capture a **mutter** zombie cycle on the same hardware (Mahmud's ms7e41) by booting Ubuntu 26.04 Desktop from a live USB, to produce the A/B story for the article — same NVIDIA-open driver, same GSP bug, different compositor.

**Procedure documented at `docs/EXPERIMENT-MUTTER-LIVE-USB.md`** — has an AI-assistant preamble, an 8-step procedure, a copy-paste cheat sheet, and the KWin reference cycles (C1/C2/C3) for comparison.

| Time | Step | Result |
|---|---|---|
| 17:00 | Decided **no Ventoy** — Ubuntu Desktop ISO is hybrid-bootable; KDE Startup Disk Creator dd's it straight to the stick. Single live session, install everything in tmpfs, no persistence needed because we never reboot the live USB. | ✓ |
| 17:05 | Wrote `docs/EXPERIMENT-MUTTER-LIVE-USB.md` (~190 lines). Sections: prerequisites, switch from nouveau to NVIDIA in one session, install zel + jq + ssh, set up SSH from laptop (critical — survives a zombie state), trigger long suspend, observe and capture from laptop SSH session, exfiltrate evidence to NAS or GitHub gist. Includes a 25-line copy-paste cheat sheet for the whole flow. | ✓ |
| 17:10 | Added an "If you are an AI assistant" preamble at the top of the experiment doc — so a fresh Claude (or other LLM) session on the live USB can be pointed at it and pick up full context: hardware identity, KWin baseline, what to do, where to write commits if needed. | ✓ |
| 17:12 | Pendrive prep handed off to Mahmud (KDE Startup Disk Creator). v0.3-experiment work pauses here until evidence is captured. | ⏸ pending |

**On-USB instructions (TL;DR for the cheat sheet):**

```bash
sudo apt update && sudo apt install -y git jq openssh-server
sudo ubuntu-drivers autoinstall
sudo modprobe nvidia 2>/dev/null
nvidia-smi || sudo systemctl restart gdm
git clone https://github.com/mmhfarooque/zombie-event-log.git
cd zombie-event-log && sudo bash install.sh && zel doctor
sudo systemctl enable --now ssh && sudo passwd ubuntu && hostname -I
# (SSH in from laptop, start: sudo journalctl -f -k > /tmp/cycle.log &)
sleep 5 && systemctl suspend
# wait 5 minutes, wake, observe screen, then on laptop SSH:
zel last 5 && sudo cp -a /var/lib/zel/cycles /tmp/mutter-evidence/
```

**Pointer for live-USB Claude session:** `cat docs/EXPERIMENT-MUTTER-LIVE-USB.md` and `cat PROJECT_LOG.md` (this file) — together they cover the whole project context. The `git log` shows what's already shipped.


### 2026-06-18 — v0.2.x classifier: post-resume-collapse detection

Real-world driver: ms7e41 hard-reset zombie on 2026-06-18. Root cause traced to the NVIDIA open-module 595.71.05 + kernel 7.0 suspend regression (VRAM restore silently fails, no kernel Xid). The cycle that froze the machine (20260618-152350) was scored clean/high by the v0.2 classifier, because it only looked at GSP heartbeat + DRM-open at the resume instant and was blind to a userspace GL collapse that surfaces minutes after a clean-looking resume.

| Time | Step | Result |
|---|---|---|
| 19:05 | Added universal signal gpu_userspace_collapse (Chromium/Electron GPU-process exits, GL context + command-buffer failures in the slice). | done |
| 19:08 | Added compositor_graphics_reset (counts KWin/mutter GL re-init attempts as rescue-attempt evidence). | done |
| 19:12 | Added boot-end correlation: map cycle boot_id to whether that boot ended uncleanly (no shutdown/reboot target, no journald stop) with no later wake = definitive zombie. Guards: skips the running boot and boots whose journal has rotated away. | done |
| 19:16 | New outcomes degraded (survived but GL stack collapsed) and post_resume_collapse (boot died after this resume). Wired into stats + catastrophic list; recovery-rate metric reworked. | done |
| 19:22 | Fixed pre-existing false positive: drm_open_failures was counting benign kwin/sddm probe failures of card0/card1/renderD12x (hybrid-GPU enumeration fallback that fires on clean cycles). Now informational only; GSP heartbeat gates the kernel-error verdict. | done |
| 19:28 | Verified: 20260618-152350 reclassifies clean to post_resume_collapse/high (gpu_userspace_collapse=7, compositor_graphics_reset=1, unclean_boot_end=1). Full re-score: 45 clean / 82 rescued / 1 degraded / 2 post_resume_collapse / 130. | done |

Lesson and next increment (v0.3 Phase 1): classification verdicts live only in the volatile per-user cache (~/.cache/zel), so clearing it after journals rotate loses history. During this session the 5 older catastrophic verdicts (late-May to early-June) could not be re-derived because their journals had aged out. Fix: persist verdict + signal counts durably into /var/lib/zel at capture time so rotation and cache clears can never erase history. Then build the failsafe ladder (notify, kwin --replace, session bounce, clean reboot instead of hard reset) behind an arm/disarm toggle.

Shipped: committed as 152219a and pushed to mmhfarooque/zombie-event-log main (authored Mahmud Farooque <farooque7@gmail.com>, personal account). NOT yet live on ms7e41 — pending sudo bash install.sh to deploy the new lib into /usr/local/share/zel (safe; preserves /var/lib/zel cycle data). Separate ms7e41 machine fix, not part of this repo: NVIDIA open-module suspend param change (NVreg_UseKernelSuspendNotifiers=1, drop PreserveVideoMemoryAllocations=1) staged at /tmp/ms7e41-zombie-fix.sh, pending a reboot.

### 2026-06-19 evening — live capture session: full failure-spectrum characterised, netconsole rig built, modprobe space ruled out

Triggered by another KWin/Plasma death + hard restart. Spent the session driving `zel` + journals + a fresh network-capture rig against ms7e41 in real time. No code shipped to this repo; the value is diagnosis + a built (then torn-down) capture harness. Installed `zel` lib is now == repo (152219a install.sh ran at some point since 06-18; that prior "pending install" note is resolved).

**Today's cycle tally (2026-06-19):**

| Time | Trigger | Kernel | Userspace | Verdict |
|---|---|---|---|---|
| 12:53 | idle auto-suspend | resumed | plasmashell OK | clean |
| 14:03 | idle auto-suspend | resumed | plasmashell OK | clean |
| 17:59 | idle auto-suspend (PowerDevil) | **never woke** — journal ends at `PM: suspend entry (deep)`, no `suspend exit`, hard reset ~19:22 | — | **ZOMBIE** (deep-suspend resume hang) |
| 19:33 | manual (live witness test) | resumed ~44s | — | clean |
| 20:18 | manual (netconsole armed) | resumed | **plasmashell SIGABRT** | degraded |
| 20:25 | manual (netconsole armed) | resumed | **plasmashell SIGABRT** | degraded |
| ~20:40 | manual (disarmed, stock) | resumed | plasmashell OK | clean (control) |

**Findings that closed off wrong leads:**
1. **KWin `Permission denied` / `Atomic modeset test failed` / `drmModeListLessees() failed` on suspend = BENIGN.** They fire on every suspend incl. cycles that resume perfectly (proven on 12:53/14:03/19:33). NOT the crash. (Corrected an early misread that took them as the smoking gun.) Matches the existing `drm_open_failures`-is-informational classifier rule.
2. **Duration-threshold theory FALSIFIED with the dataset.** Across 130 cycles: `20260615-074757` collapsed at **26 min** (post_resume_collapse) while `20260604-223520` resumed **clean at 392 min (6.5h)**. Of the 4 bad outcomes, 2 were under 1h, 2 over. Duration is neither necessary nor sufficient — it is a probabilistic resume race, not a timer.
3. **RAM-reseat ruled out** — deterministic trigger (logind idle-suspend) + clean intermittency + known driver/kernel = software, not contacts.
4. **Daughter power-button confound raised + cleared** — plasmashell crashes on untouched clean resumes.

**The bug, fully characterised — one root, three severities:**
- Root: GPU/VRAM + GL-context state not reliably restored across S3 suspend on this stack.
- Mild: clean resume.
- **Degraded (`gpu_userspace_collapse`):** on resume, plasmashell processes a Wayland expose, tries to rebuild its RHI, finds the GL context gone → `QRhiGles2: Context is lost` → `Failed to create RHI (backend 2)` → `Failed to initialize graphics backend for OpenGL` → Qt `qFatal()` → SIGABRT → KCrash → auto-respawn. Backtrace: `QWaylandWindow::sendExposeEvent` → `updateExposure` → QtQuick fatal. Modules: `libnvidia-egl-wayland`, `libEGL_mesa`, `libGLX`. Coredumps 20:19:30 + 20:26:29.
- **Zombie:** full kernel resume hang (17:59), machine wedged, hard reset only recovery.

**modprobe config space — now EXHAUSTED (fix is not a setting):**
- `NVreg_PreserveVideoMemoryAllocations=1` is the **proprietary**-driver mechanism. On the open module it half-wires a procfs suspend path the open module does not expose and *matched* the delayed post-resume collapse (upstream open-gpu-kernel-modules issues 1142 / 1157). Removed 06-18. **Do NOT re-enable on the open module** — staging that was proposed this session and correctly aborted after reading the conf comment.
- `NVreg_UseKernelSuspendNotifiers=1` is the open-module-correct mechanism, active now (`/proc/driver/nvidia/params` reads `PreserveVideoMemoryAllocations: 2`, `UseKernelSuspendNotifiers: 1`). Context loss persists *with it on*.
- Both mechanisms tried → conclusion: a modprobe toggle will not fix this. Next levers are **path 2 (patch the open module)** or **path 3 (driver/kernel version bump)**.
- Other relevant: `NVreg_TemporaryFilePath=/var` (VRAM save path — untested whether the save actually succeeds); 2nd file `nvidia-drm-fbdev-suspendfix.conf` exists, not yet read; `nvidia-suspend/resume/hibernate.service` all enabled.

**netconsole capture rig — BUILT, PROVEN, then learned its hard limit:**
- Receiver: rootless Python UDP listener on NAS (Synology DS923+, `<nas-user>@<NAS_IP_A>`, key `~/.ssh/nas-git`), port 6666, log at `/volume1/homes/<nas-user>/zel-netconsole.log`. NAS busybox lacks nc/socat/pgrep/ss — used Python + `/proc/net/udp` (port hex `1A0A`) + ssh-`cat` delivery (SFTP is chrooted, scp fails). No root on NAS (sudo denied) → cannot touch shares/backups by construction.
- Sender: dynamic netconsole via configfs, 3 redundant targets — NAS NICs eth2/.96 `<NAS_MAC_A>` (2.5GbE static), eth1/.97 `<NAS_MAC_B>`, eth0/.98 `<NAS_MAC_C>`. PC iface `enp130s0` / `<PC_LAN_IP>`. Set `console_suspend=N` + `printk=8`.
- Scripts: `~/DEV/nvidia-resume-fix/{nas-listener-v01.py, arm-netconsole-v01.sh, disarm-netconsole-v01.sh}`.
- **PROVEN** end-to-end on clean cycles. **LIMITATION (key result):** ~7s resume **blind spot** — the NIC is down during the resume window when the killer GPU/DRM messages print, so netconsole alone CANNOT capture the zombie or the plasmashell context-loss. (plasmashell crash is userspace anyway → journald only, never netconsole.)
- pstore: mounted but **no working backend** (no ERST table, no ramoops) → captures nothing; a silent hang has no oops to catch regardless.
- NIC-independent options for the zombie: **serial console** (`/dev/ttyS0`,`ttyS1` exist — needs COM header + cable) or **kdump** (disk vmcore; needs crashkernel reboot) fronted by `hung_task_panic`/`softlockup_panic`/magic-sysrq to turn the silent wedge into a catchable panic.

**OPEN QUESTION carried to next session — `console_suspend=N` correlation:**
- Armed (`console_suspend=N`): 2/2 resumes crashed plasmashell. Disarmed (stock `console_suspend=Y`): 1/1 clean.
- NOT conclusive: ~1-in-4 base crash rate means the single clean disarmed resume had ~75% chance of being luck. **Need ~5 disarmed resume samples** to confirm/deny. Hypothesis: keeping the console alive across suspend perturbs GPU resume timing and tips borderline resumes into context-loss. If true, that is a genuine finding (and a clue about the race).

**Hardware/feasibility for path 2:** Core Ultra 5 245K (Arrow Lake-S) / MSI PRO B860-P / kernel 7.0.0-22 / hybrid Intel iGPU + RTX 3060 (GA106) / NVIDIA Open module 595.71.05 / KDE Wayland. Secure Boot ON but **MOK already enrolled + `kmodsign` present** → signing a self-built module is feasible. `open-gpu-kernel-modules` cloned at tag **595.71.05** in `~/DEV/nvidia-resume-fix/` (resume path: `kernel-open/nvidia/nv-pci.c` etc.), toolchain + headers present.

**End-of-session state (all reverted to stock):** PC — netconsole unloaded, `console_suspend=Y`, modprobe conf UNCHANGED (still 06-18 config). NAS — listener killed (pid 5057, port free), capture log preserved (255 lines). No persistent prod changes.

**Next session, in order:**
1. Gather ~5 stock-config resume samples to settle the `console_suspend=N` question (just normal use; watch for the plasmashell crash dialog).
2. If pain needs stopping meanwhile: `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target` (one line, reversible) — the only thing that reliably stops the zombie too.
3. Pick fix path: **2** (instrument/patch open module resume + VRAM-restore, sign w/ MOK) vs **3** (newer open-module tag / kernel that may already fix the resume race — check issues 1142/1157 status). Read `nvidia-drm-fbdev-suspendfix.conf` and verify the `/var` VRAM save actually succeeds first.
4. Optional: kdump + panic-on-hang + sysrq, or serial console, to capture the full zombie (netconsole proven blind in the resume window).

### 2026-06-19 late — path 2 opened: stock module BUILDS, preservation-setting class FALSIFIED, root localised to nvidia-drm sync + Qt

Went the hard way on the open module. Two outcomes, both real.

**Stock build WORKS (the path-2 gate):** `make -j modules` in `~/DEV/nvidia-resume-fix/open-gpu-kernel-modules` (tag 595.71.05) compiled all 5 modules clean against kernel 7.0.0-22 headers: `nvidia.ko` (36M), `nvidia-uvm.ko` (57M), `nvidia-modeset.ko`, `nvidia-drm.ko`, `nvidia-peermem.ko`. (BTF gen skipped — no vmlinux — harmless.) So we can build, and with the enrolled MOK + `kmodsign` we can sign and load a patched module. Build log: `open-gpu-kernel-modules/build.log`.

**Root-cause hunt — the entire "preservation config" class is now falsified (traced in source, not guessed):**
- `nv_dev_needs_vidmem_preservation()` (nv.h:1341) returns **true** for the RTX 3060 (only false for Tegra/SoC iGPU) → restore is NOT skipped.
- No `WARN_ON` fired on either resume (20:19 / 20:26) → `nvidia_resume()` + `nv_restore_user_channels()` ran and returned NV_OK.
- The param reads `2` because the open-module **default is AUTO** (`NV_DEFINE_REG_ENTRY(...AUTO)`, nv-reg.h:1049). Removing the explicit `=1` on 06-18 just fell back to AUTO.
- AUTO path (osinit.c:955): `nv->preserve_vidmem_allocations = os_supports_kernel_suspend_notifiers()` and that returns `NVreg_UseKernelSuspendNotifiers==1` → **TRUE on this box**. So AUTO + notifiers → `memmgrSetPmaForcePersistence(TRUE)`. **Full VRAM preservation is already ENABLED, running, and reporting success.**
- Conclusion: it is NOT a modprobe setting, NOT skipped restore, NOT RM-level VRAM loss. (`Preserve=1` would additionally trip the `!is_procfs_suspend` error at nv.c:4693 under the notifier path — that is the 06-18 zombie mechanism — so still do NOT set it.)

**Where the evidence now points (next session targets):**
1. **nvidia-drm sync layer** — the ONLY resume error was `[nvidia-drm] *ERROR* Failed to register auto-value-update on pre-wait value for sync FD semaphore surface` (GPU ID 0x200) at 20:18:35 + 20:26:15. A DRM fence/semaphore-surface object not surviving suspend *despite* VRAM preservation. Instrument `nvidia-drm` semaphore-surface restore (`__nv_drm_semsurf_wait_fence_work_cb` and its setup) — patchable, module builds.
2. **Qt/plasma fragility** — Qt6 RHI hits `Context is lost` → `qFatal()` → abort instead of rebuilding the context. That half is upstream Qt/plasma, not NVIDIA; a lost context *should* be recoverable. Worth checking Qt RHI context-robustness handling / any plasma env knob.
3. **Path 3 (version bump)** still a strong candidate — a newer open-module tag / kernel may fix the sync-surface restore. Cheaper than patching if it works; check open-gpu-kernel-modules changelog for sync FD / semaphore-surface suspend fixes after 595.71.05.

State unchanged from prior entry (all stock; nothing installed; build artifacts are throwaway in the workspace).

### 2026-06-19 night — DECISION: upgrade driver to 610.43.02 (path 3), build pre-validated, install staged (pending Secure Boot off)

User at ultimatum (fix tonight or back to Windows). Chose the version bump and specifically the newest branch (v6 = 610.43.02).

**Why path 3 not path 2:** Ubuntu is frozen at 595.71.05 (it is the newest in-repo; 580/575/570 are older). `apt` cannot upgrade. But upstream `open-gpu-kernel-modules` has newer tags: 595.80, 595.84, and **610.43.02**. A newer release is the genuine-fix shot (corrected upstream code, not a workaround) and far faster than hand-patching nvidia-drm sync-surface restore.

**Pre-validation done (de-risk before touching BIOS):**
- `610.43.02` open module **BUILDS CLEAN on kernel 7.0.0-22** — cloned to `~/DEV/nvidia-resume-fix/ogkm-610`, `make modules` produced all 5 `.ko`, only harmless objtool RETHUNK warnings, zero errors.
- `.run` installers downloaded to `~/DEV/nvidia-resume-fix/`: `NVIDIA-Linux-x86_64-610.43.02.run` (440MB, primary) + `NVIDIA-Linux-x86_64-595.84.run` (403MB, safer same-branch fallback if 610 misbehaves at runtime).

**Blocker that MUST be cleared first — Secure Boot:**
- SB is **ENABLED** (confirmed twice: `mokutil --sb-state` = enabled; efivar `SecureBoot-...` data byte = 1). User wrongly believed it was off.
- **MOK keystore `/var/lib/shim-signed/mok/` is EMPTY** — no user signing key. Current 595.71.05 module loads only because Canonical signed it. A `.run`/self-built 610 module would be **unsigned → blocked by SB → black screen**.
- Decision: **disable Secure Boot in BIOS** for the install (simplest tonight; re-enable + enroll MOK + sign later once proven).
- Safety checks before SB-off: **no LUKS / no TPM auto-unlock** (so no passphrase prompt on Linux). BUT **dual-boot Windows present** (`Boot0002 Windows Boot Manager`) → if it has BitLocker, expect a recovery-key prompt next time Windows boots after SB-off (Linux unaffected). Recovery key at account.microsoft.com/devices/recoverykey.

**Install procedure (staged, pending SB-off + my re-verify SB=0):**
1. (BIOS) Disable Secure Boot → Save & Exit → boot to Linux. Claude re-checks `mokutil` reads disabled BEFORE install.
2. `Ctrl+Alt+F3` → login → `sudo systemctl isolate multi-user.target`
3. `sudo sh ~/DEV/nvidia-resume-fix/NVIDIA-Linux-x86_64-610.43.02.run --kernel-module-type=open` (accept license; continue past the distro-driver warning; yes to rebuild initramfs)
4. `sudo reboot`
5. Verify `cat /proc/driver/nvidia/version` = 610.43.02 → deep-S3 suspend → check plasmashell survives (the bug repro). Clean = real fix.

**Recovery net (if black screen / broken):** `Ctrl+Alt+F3` → `sudo bash ~/DEV/nvidia-resume-fix/RECOVERY-restore-stock-driver.sh` (uninstalls .run, reinstalls `nvidia-driver-595-open=595.71.05-0ubuntu0.26.04.1` + initramfs) → reboot → back to exactly current state.

**CURRENT STATE at log time:** still 100% stock — nothing installed, SB still ON, driver still 595.71.05. Next action = user reboots to disable Secure Boot, returns, Claude verifies SB=off, then Phase 2 install. If 610 fails at runtime, fall back to 595.84, then to recovery.

### 2026-06-19 ~22:45 — 610.43.02 INSTALLED (3rd attempt); plasmashell crash = KDE-side; ZOMBIE verdict pending overnight

Secure Boot disabled in BIOS. Install took 3 attempts, each peeling one blocker:
1. SB on → unsigned module blocked (fixed: SB off).
2. old 595 driver pinned by nvidia-persistenced → version mismatch (fixed: script stops daemons + `modprobe -r` before install).
3. apt 595 module files still on disk → `nvidia.ko(610)`+`nvidia-modeset.ko(595)` mismatch (fixed: script purges apt 595 stack first; blast radius verified safe via `apt-get -s purge` sim — only nvidia-595 pkgs, NOT desktop/kernel/xorg-core).

3rd run succeeded: `/proc/driver/nvidia/version` = 610.43.02, `nvidia.ko`+`nvidia-modeset.ko` both 610, nvidia-smi healthy, desktop up. (Did the install over SSH from the Mac because VT-switch to a console showed a dark screen — the GPU modeset-on-VT-switch is itself flaky; installed `openssh-server`, opened ufw 22.)

**Findings:**
- **610 did NOT fix the plasmashell resume crash.** Signature shifted 595 SIGABRT(`Context is lost`) → 610 **SIGSEGV**, but plasmashell still dies on every resume. Persisting across two very different drivers **confirms it is KDE/plasmashell-side, not driver.** kwin survives intact (same pid, no restart) every cycle → the display always returns; the crash is cosmetic and auto-respawns. Proven NOT a zombie precursor (no kernel stall in the resume window).
- **ZOMBIE verdict still open.** One 610 resume survived clean (no `hung_task`/`Xid`/stall). User left the PC on S3 sleep **overnight 2026-06-19→20** as the long-duration test (long suspends were when the worst zombie hit). Morning: boot_id unchanged = survived (610 likely fixed it); hard-reset needed = zombie alive → driver-deep, go path 2 (patch nvidia-drm sync-surface, source in `~/DEV/nvidia-resume-fix/ogkm-610`) or different kernel.

**Decision groundwork (see `~/DEV/nvidia-resume-fix/SITUATION-BRIEF.md`):** if zombie gone → war won, only the cosmetic crash remains → tolerate it or `apt install` GNOME on Ubuntu (mutter dodges it, no reinstall). Distro options weighed: GNOME-on-Ubuntu (cheapest), Fedora 44 (btrfs+akmod but coin-flip on zombie, same driver), COSMIC (least mature, wrong tool), Plasma 6.7 (no clean source/rollback on ext4). Bigger picture: user's appetite (newest DE + rollback) = Fedora/openSUSE+btrfs territory, not Ubuntu LTS+ext4. Follow-ups: re-enable Secure Boot + MOK-sign 610 once proven; SB currently OFF.

### 2026-06-20 morning — OVERNIGHT TEST PASSED: 610 beat the zombie (strong, not yet statistical)

Left on S3 overnight. Result: **survived clean.** `23:35:33 PM: suspend entry (deep)` → `05:05:16 PM: suspend exit` → `Operation suspend finished` = a **5.5-hour deep suspend resumed cleanly.** Same boot_id (no hard-reset), uptime 6h27m, zero hung_task/rcu/Xid/lockup, nvidia-smi healthy 35°C. Context: the original zombie was an 83-min suspend that never woke on 595 — 610 passed a suspend 4× longer (the worst-case long-duration condition). **And the cosmetic plasmashell crash did NOT recur on the 05:05 resume** (plasmashell still pid 5694 from last night's respawn → survived this wake untouched).

**Verdict:** 610.43.02 appears to fix the zombie. Caveat — this is ~2 resume cycles; the zombie was intermittent (~1-in-4), so call it CONFIRMED only after several more days of normal-use resumes with no hard-reset. But a 5.5h clean resume on the worst-case condition is the strongest single data point we could get. Distro/DE switch = **moot if this holds** (stay KDE + 610).

**Two loose ends (housekeeping, not blockers):**
1. **Secure Boot is OFF** — 610 .run module is unsigned. Re-enable SB + generate/enroll a MOK + sign the 4 modules (nvidia, nvidia-modeset, nvidia-drm, nvidia-uvm) so it loads under SB again (also clears the dual-boot Windows/BitLocker exposure).
2. **No DKMS** — 610 was .run-installed without dkms. **Next Ubuntu kernel update will break it** (module won't auto-rebuild → black screen on the new kernel). Fix: register dkms, OR `apt-mark hold` the kernel, OR re-run the .run after each kernel bump. Flag before any kernel upgrade.

### 2026-06-20 morning — DKMS DONE; fix sealed
Ran `~/dkms-610.sh` (over Mac SSH): installed `dkms`, re-ran the 610 .run with `--dkms --kernel-module-type=open`. Post-reboot verified: driver 610.43.02 loaded, `dkms status` = `nvidia/610.43.02, 7.0.0-22-generic: installed`, desktop healthy, `10_nvidia.json` EGL vendor config present (the libglvnd warning during install was harmless). **Kernel updates are now safe — DKMS rebuilds the module on each one.** No kernel hold needed. Secure Boot intentionally left OFF (user's call; unsigned module is fine with SB off). 

**STATUS: RESOLVED (pending a few more days of normal-use resumes to call the zombie statistically dead).** Loose ends both closed. Remaining = optional/creative: publish the tooling + case-study to git; write the blog post. Driver-maintenance note for future: this is a .run+dkms install (NOT apt) — if ever switching back to apt nvidia, purge the .run first via `nvidia-installer --uninstall`.

### 2026-06-20 — published case study; GNOME-safety analysis; driver-update model

**Published** this case study + sanitised scripts to `case-studies/nvidia-open-s3-resume-hang/` (LAN/host specifics redacted to placeholders; verified 0 sensitive hits on the live remote). Pushed to `main` (auth: `gh auth switch --user mmhfarooque` to push, switched back to `mahmudfarooque`). Blog draft written for mfaruk.com (kept local, pending review — NOT in git). Hero-image prompt provided.

**Driver-update model going forward:** now OFF apt auto-updates (apt nvidia stack purged; 610 is a .run+dkms install). DKMS rebuilds 610 for new *kernels* only — it does NOT bump driver *versions*. To update the driver: re-run a newer `.run` (manual), OR return to apt once Ubuntu ships a new-enough driver (`nvidia-installer --uninstall` then `apt install nvidia-driver-XXX-open`). **Trap:** never let apt / `ubuntu-drivers autoinstall` reinstall an nvidia driver alongside the .run — recreates the dual-module collision.

**GNOME-safety question (is it now safe to switch DE?) — analysed via zel:** All 6 post-610 cycles classify `clean / mild / GSP=0`, incl. the 5.5h overnight one: `gsp_heartbeat_timeouts=0, storm_duration=0, compositor_graphics_reset=0`. Significance: on 595 a rescued cycle showed GSP timeouts + tens of thousands of KWin re-renders (KWin actively rescuing — per origin note KWin rescues ~96% where mutter never recovers). On 610 **there is no storm at all** → 610 fixed the ROOT, KWin's rescue net is no longer load-bearing → **GNOME would NOT re-expose the zombie** (and would kill the cosmetic plasmashell crash). Caveat: 6 cycles, day one; want a week / a batch of clean GSP=0 cycles (esp. long suspends) to confirm. Low-risk path when ready: install `gnome-shell` ALONGSIDE Plasma, pick session at SDDM login (fully reversible, KDE stays as fallback). Watch signal: any reappearing GSP heartbeat timeout / `rescued` outcome = net still load-bearing → stay on KDE.

**Next:** user rebooting to run a deliberate batch of suspend/resume tests (mix short+long). Review afterward with `zel last N` + `zel stats` — verdict = zero GSP timeouts across the batch.

### 2026-06-20 — downstream wins from the fix
- Post-610 test batch continued clean (e.g. 20260620-064401 clean/GSP=0); streak holding, zombie looks dead pending more days of normal use.
- **Blog published** — the companion write-up to this case study went live on mfaruk.com (the fixed GPU's story).
- **Local AI image gen** now runs on the rescued 3060 — ComfyUI + FLUX.1-dev fp8 in an isolated Python 3.12 venv (torch 2.9.1+cu130), ~90s/image, free/private. Used it to make the blog hero. Saved as the `GEN LOCAL IMG` callout for future use. (The whole point: the GPU we fought to fix now does real work.)
- **Weekly driver-update watcher** added (`nvidia-update-check.sh` + systemd user timer) since the .run+dkms driver is now off apt's auto-updates — it notifies only when a newer upstream driver exists or Ubuntu's repo finally catches up (the cue to return to apt).
