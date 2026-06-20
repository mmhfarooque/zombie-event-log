# Case study: NVIDIA open-module S3 resume hang (Arrow Lake + RTX 3060, kernel 7.0)

A real-world debugging session that drove this tool. Hardware/LAN specifics are redacted (placeholders like `<PC_LAN_IP>`, `<NAS_IP_A>`, `<nas-user>`).

## The stack
Intel Core Ultra 5 245K (Arrow Lake-S) · MSI B860 · kernel 7.0 (mainline) · hybrid Intel iGPU + NVIDIA RTX 3060 (GA106) · **NVIDIA open kernel module** · KDE Plasma / Wayland · S3 deep suspend.

## The bug — one root, three severities
On resume from S3:
1. **Clean** (rare).
2. **Degraded** — `plasmashell` crashes on wake (`QRhiGles2: Context is lost` → `qFatal`), but `kwin` survives so the display returns and the shell auto-respawns. Cosmetic, KDE-side (persisted across two driver versions → not a driver bug).
3. **Zombie** (~1 in 4) — full kernel resume hang, journal ends at `PM: suspend entry`, hard reset the only recovery.

## What was ruled out (with evidence)
- kwin `Permission denied` / `Atomic modeset test failed` on suspend = **benign** (fire on clean cycles too).
- RAM reseat (deterministic trigger + known driver/kernel = software).
- Duration-threshold theory (a 26-min suspend collapsed; a 6.5h one resumed clean → probabilistic race, not a timer).
- **Video-memory-preservation config** — traced in the open-module source: AUTO mode + `UseKernelSuspendNotifiers=1` already sets `preserve_vidmem_allocations = TRUE`; full VRAM preservation was already on and succeeding. Do **not** set `NVreg_PreserveVideoMemoryAllocations=1` on the open module (proprietary mechanism; half-wires a procfs suspend path the open module doesn't expose — see open-gpu-kernel-modules issues #1142 / #1157).
- netconsole capture has a ~7s resume **blind spot** (NIC asleep when the GPU bring-up messages print).

## The fix
The fault lives in the driver's resume path, and the distro shipped an older release. Solution: build/install a **newer upstream NVIDIA open driver** the distro hadn't packaged yet, then register it with **DKMS** so it survives kernel updates.

Install gotchas hit, in order (each script step addresses one):
1. Secure Boot blocks an unsigned self-built module → disable SB (or enroll a MOK and sign).
2. The running driver is pinned by `nvidia-persistenced` → stop the daemons and `modprobe -r` the stack before installing.
3. The distro driver's module files collide with the `.run`'s → **purge the distro NVIDIA stack first** (simulate the purge to confirm it doesn't drag the desktop/kernel/xorg-core out).

**Result:** a 5.5-hour overnight S3 suspend resumed clean — four times longer than the suspend that used to zombie the machine.

## Scripts
| File | Purpose |
|---|---|
| `install-newer-driver.sh` | Stop desktop, purge colliding distro driver, install the upstream `.run` (open module), reboot. Edit the `RUN=` path. |
| `register-dkms.sh` | Re-run the `.run` with `--dkms` so the module auto-rebuilds on kernel updates. |
| `recovery-restore-distro-driver.sh` | Roll back: uninstall the `.run`, reinstall the distro driver, rebuild initramfs. |
| `netconsole-arm.sh` / `netconsole-disarm.sh` | Stream the kernel log over UDP to another machine across suspend/resume (set `console_suspend=N`). Fill in your own target IPs/MACs. |
| `netconsole-listener.py` | Rootless UDP listener for the receiving machine. |

> These are reference scripts from one machine — read them, set your own IP/MAC/path placeholders, and keep a tested rollback before running anything that swaps a live driver.
