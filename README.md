# Zombie Event Log

Passive suspend/resume telemetry for Linux desktops.

`zel` records every suspend and resume on your machine, then tells you whether your compositor recovered cleanly, rescued itself, or left you with a zombie wake. Works on KDE, GNOME, and Cinnamon. One-time install; zero idle cost.

## Why?

Some Linux laptops and desktops wake from suspend into a black-screen, unresponsive "zombie" state — usually due to a GPU driver that fumbles the resume handshake. Whether you actually *see* the zombie depends on your compositor: some retry aggressively and recover; others give up. Zombie Event Log measures the difference on your own machine, so you can answer questions like:

- How often does my compositor rescue me from a bad resume?
- Is the situation getting worse after a kernel/driver upgrade?
- When the rescue fails, what was different about that cycle?

The flagship example is the NVIDIA-open-driver GSP heartbeat bug (see `examples/nvidia-gsp-bug-2026/`), where KWin recovers ~96% of resumes and mutter rarely does — but the framework is general and catches AMD, Intel, and ACPI suspend issues too.

## Install

```bash
git clone https://github.com/mmhfarooque/zombie-event-log.git
cd zombie-event-log
sudo bash install.sh
```

Verify:

```bash
zel doctor
```

## Usage

```bash
zel stats                # summary across all cycles
zel last 10              # last 10 cycles, table view
zel catastrophic         # cycles where the compositor did not recover
zel show 20260502-145503 # full evidence dump for one cycle
zel compare A B          # side-by-side classifier output
zel export out.jsonl     # all cycles as JSONL for further analysis
```

After installing, suspend and resume your machine once. Then `zel last` will show the cycle.

## How it works

| Component | Path | Role |
|---|---|---|
| Hook | `/usr/lib/systemd/system-sleep/50-zel` | Runs on every suspend (pre) and resume (post). Records cycle metadata to `/var/lib/zel/cycles/<id>.json`. Exits in milliseconds. |
| Cycles store | `/var/lib/zel/cycles/` | One JSON file per suspend/resume. ~2 KB each. |
| CLI | `/usr/local/bin/zel` | Reads cycles, pulls journal slices on demand, runs the per-compositor adapter, prints results. |
| Adapters | `/usr/local/share/zel/lib/adapters/` | Per-compositor classifiers (`kwin.sh`, `mutter.sh`, `muffin.sh`). |

Classification is **lazy** — done at query time, not in the hook — so re-runs benefit immediately when adapters improve, and the hook stays trivial.

## Supported desktops

| Compositor | Status | Outcome confidence |
|---|---|---|
| KWin (Plasma 5/6, Wayland or X11) | First-class | High — validated against real GSP-zombie events |
| mutter (GNOME Shell) | Partial | Low — needs more ground truth |
| Muffin (Cinnamon / Mint) | Partial | Low — same |
| Sway, Hyprland, XFCE/xfwm4 | Not yet | Detection only, no adapter |

See `docs/SUPPORTED-DESKTOPS.md` for what's missing and how to contribute an adapter.

## Distribution support

| Distro | Method | Status |
|---|---|---|
| Ubuntu / Kubuntu | `bash install.sh` | Tested |
| Linux Mint | `bash install.sh` | Should work (Cinnamon adapter is partial) |
| Fedora | `bash install.sh` | Should work |
| Arch / Manjaro | `bash install.sh` (PKGBUILD planned) | Should work |
| Debian | `bash install.sh` | Should work |

`.deb`, `.rpm`, and AUR packaging are scaffolded under `packaging/` and on the roadmap.

## Privacy

`zel` runs entirely on your machine. Nothing is uploaded anywhere. The cycle files live at `/var/lib/zel/cycles/` and you can inspect or delete them at any time.

## Roadmap

- **v0.2** — `zel-gui` (GTK4 + libadwaita): modern Linux desktop GUI for browsing, copying, and clearing logs
- **v0.3** — first-class mutter adapter from real GNOME zombie ground truth
- **v0.4** — `.deb`, `.rpm`, AUR `PKGBUILD`, **Flatpak** packaging
- **v0.5** — TUI (`zel-tui`) for live browsing
- **v1.0** — Rust rewrite of the CLI (`zel`): single static binary, `clap` arg parsing, `serde` JSON, `systemd::journal` for direct journal access. Hook stays bash (correct for the systemd-sleep context). Bash CLI moves to `experimental/bash-prototype/` for reference.
- **v1.1** — opt-in upload of anonymised classification stats to compare across machines

## Tech stack (current and target)

| Component | v0.1 (now) | v1.0 (target) | Why |
|---|---|---|---|
| Hook (`50-zel`) | bash | bash | Runs in minimal systemd-sleep context; sub-ms start budget; correct tool. |
| CLI (`zel`) | bash | **Rust** (`clap`, `serde`, `systemd-journal`) | Single static binary, future-proof, better JSON & journal parsing. |
| GUI (`zel-gui`) | (planned for v0.2) | **GTK4 + libadwaita + Python** | Modern GNOME HIG, native look on all desktops, fast iteration. May port to Rust + gtk4-rs later. |
| Distribution | `bash install.sh` | `.deb` / `.rpm` / AUR / **Flatpak** | Flatpak as bleeding-edge sandboxed delivery; native packages for traditional users. |

## Contributing

Got a zombie? Open an issue with the output of `zel show <id>` and `journalctl --since "<suspend_time>" --until "<resume_time>+5min"`. Adapter improvements welcome.

## License

MIT — see `LICENSE`.

## Origin

Built out of the [NVIDIA-GSP suspend investigation, May 2026](examples/nvidia-gsp-bug-2026/) — a real-world case where the same hardware behaved very differently under KDE vs GNOME.
