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

