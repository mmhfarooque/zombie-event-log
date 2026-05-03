# Experiment — Capturing a mutter zombie cycle on Ubuntu Live USB

Use this when you've booted Ubuntu Desktop from a live USB on the same hardware that reproduces the NVIDIA-open GSP suspend bug, and want to observe how mutter handles it (vs KWin, which we already have data for).

> **If you are an AI assistant (Claude or other) reading this in a fresh live-USB session with no prior context:**
>
> - You are running on Mahmud Farooque's ms7e41 workstation, booted from an Ubuntu 26.04 Desktop live USB.
> - The host install is normally Kubuntu 26.04 with KDE Plasma 6 and NVIDIA-open driver 595.58.03.
> - We have **proven** on the KDE side that this hardware fires the NVIDIA GSP heartbeat bug on 100 % of suspends and KWin rescues 100 % (3-cycle dataset; see `PROJECT_LOG.md` and `git log` in this repo).
> - The point of this live-USB session is to capture the **mutter** (GNOME) side of the same A/B: same hardware, same driver, different compositor.
> - Help Mahmud follow Steps 1–8 below in order. Skip nothing. The capture phase (Step 6 onwards) is the only data we'll get — there's no persistence on this stick, so don't reboot the live session unless absolutely necessary.
> - The reference KWin cycles are listed at the bottom of this file under "Reference cycles for comparison". Once a mutter cycle is captured, your job is to verify outcome ≠ rescued (or = rescued — we want the truth) and help exfiltrate the evidence to NAS / GitHub gist before power-off.
> - Project owner repo: <https://github.com/mmhfarooque/zombie-event-log>. Personal account `mmhfarooque` / email `farooque7@gmail.com`. The Kubuntu host has identity routing set up — but **on this live USB, git is unconfigured**. If commits are needed, set `user.name` and `user.email` first.

**Prerequisites:**
- Ubuntu 26.04 Desktop ISO burned to a USB stick (KDE Startup Disk Creator, Rufus, `dd`, etc.)
- Booted the live session — you're at the GNOME desktop running from the stick
- A second machine on the same LAN (laptop, phone with `Termius`, anything with SSH) — needed because if mutter zombies, the local screen is dead but SSH keeps working
- Internet (Ethernet or Wi-Fi)

Run everything below from a terminal **on the live USB session** unless tagged `[laptop]`.

## 1. Verify the live session

```bash
lsb_release -a               # Ubuntu 26.04
uname -r                     # kernel version
lspci -nnk | grep -iE 'vga|3d' -A 2   # GPU + active driver — nouveau by default
nvidia-smi 2>&1 | head -2    # likely "command not found" pre-driver-install
```

## 2. Switch from nouveau to NVIDIA driver — single live session, no reboot

```bash
sudo apt update
sudo ubuntu-drivers autoinstall      # picks the recommended NVIDIA package, builds DKMS module
sudo modprobe -r nouveau             # unload nouveau (may fail if X is using it; that's OK)
sudo modprobe nvidia                 # load NVIDIA proprietary/open
nvidia-smi                            # MUST work — confirms GSP firmware loaded
```

If `modprobe nvidia` fails because nouveau is still pinned by the X server, you can usually still proceed — what matters is that the NVIDIA module is installed and gets loaded on the **next** kernel boot. For our purposes the modprobe attempt is enough to confirm the package is present; the actual GSP-bug reproduction happens on the next suspend/resume cycle either way.

If `nvidia-smi` still doesn't work, fall back to:

```bash
sudo systemctl restart gdm           # this does effectively log you out + back in
                                     # (you'll have to re-login on the GNOME greeter)
```

After re-login, `nvidia-smi` should report the GPU.

## 3. Install zel + jq

```bash
sudo apt install -y git jq openssh-server
git clone https://github.com/mmhfarooque/zombie-event-log.git
cd zombie-event-log
sudo bash install.sh
zel doctor                           # should report all green: hook installed, journalctl, loginctl, current desktop = gnome-shell
```

`zel doctor` should now show `current desktop: gnome-shell (GNOME)` — that's the variable we're flipping vs your KDE captures.

## 4. Set up SSH from your laptop *(critical — survives a zombie state)*

On the live USB:

```bash
sudo systemctl enable --now ssh
sudo passwd ubuntu                   # set a temporary password
ip -4 addr | grep inet | grep -v 127  # note the LAN IP
hostname -I                          # alternative way to see IPs
```

On your laptop:

```bash
[laptop] ssh ubuntu@<live-usb-IP>
[laptop] # leave this session open. If mutter zombies, this is your only window in.
```

In the SSH session, start a streaming journal capture:

```bash
[laptop] sudo journalctl -f -k > /tmp/mutter-cycle-journal.log &
```

## 5. Trigger the cycle

You want a long nap (5+ minutes) — short naps don't always trigger a render storm. From the live USB session:

```bash
sleep 5 && systemctl suspend         # 5-second window to look away from the screen
```

Wait at least 5 minutes (we know from the C1 / C2 / C3 dataset that nap length scales with storm severity), then wake by pressing a key or moving the mouse.

## 6. Observe and capture

**Watch the screen** — what you see is the data:

| Outcome | What it looks like |
|---|---|
| Clean wake | Login prompt or unlocked desktop, normal cursor, no glitches |
| Mild glitch | Brief tearing or one black flash, then recovers in seconds |
| Catastrophic zombie | Black or frozen screen, no cursor, keyboard does nothing visible. **mutter is dead but the kernel and SSH are alive.** |

In all cases, run from the laptop SSH session:

```bash
[laptop] sudo cat /var/lib/zel/cycles/*.json     # the captured cycle metadata
[laptop] zel last 5                              # classifier output (works even if local desktop is dead)
[laptop] zel show $(zel last 1 | tail -1 | awk '{print $1}')   # full evidence dump for the most recent cycle
```

Save everything before you reboot — live USB has no persistence, all state evaporates when the box powers off.

## 7. Exfiltrate the evidence

To your NAS (you've got `mimosaw_cloud.local` set up at home):

```bash
mkdir -p /tmp/mutter-evidence
sudo cp -a /var/lib/zel/cycles /tmp/mutter-evidence/
sudo journalctl -k --since "30 min ago" > /tmp/mutter-evidence/kernel-journal.txt
sudo journalctl --since "30 min ago" -u gdm.service -u systemd-logind > /tmp/mutter-evidence/userspace-journal.txt
zel last 20 > /tmp/mutter-evidence/zel-last.txt 2>&1
zel stats > /tmp/mutter-evidence/zel-stats.txt 2>&1
sudo cp -r ~/.cache/zel /tmp/mutter-evidence/zel-classifier-cache/

# To NAS via SMB (if it auto-mounts to /mnt/nas or similar) — adjust path
# Or scp to your laptop:
scp -r /tmp/mutter-evidence ubuntu@<your-laptop-IP>:/tmp/
```

Or upload to a private GitHub gist:

```bash
sudo apt install -y gh
gh auth login
cd /tmp/mutter-evidence
tar czf evidence.tar.gz *
gh gist create --secret evidence.tar.gz
```

## 8. What to do with the data

When you're back on Kubuntu, `git pull` zombie-event-log and the new evidence informs:

1. **mutter adapter ground truth** — the real mutter journal patterns, timestamps, error counts. Goes into `lib/adapters/mutter.sh` (currently a stub).
2. **Article update** — concrete A/B comparison: same hardware, KWin says "rescued" vs mutter says "catastrophic". This is the headline.
3. **Rescuer feasibility** — if mutter zombied, did anything KWin-style retry happen at all? Is there ANY render attempt post-resume? Decides whether the udev-trigger approach in `mutter-igniter` (planned v0.3) is feasible.

## 9. If the zombie wins (no recovery)

You may need to hard-reboot the live USB (long-press power). That's fine — you've already got the journal in your laptop's SSH session, and the cycle.json on the laptop. Reboot, copy the laptop logs back to Kubuntu, analyse there.

## Cheat sheet (paste-as-block)

```bash
# After booting Ubuntu live USB, all in one terminal:

sudo apt update && sudo apt install -y git jq openssh-server
sudo ubuntu-drivers autoinstall
sudo modprobe nvidia 2>/dev/null
nvidia-smi || sudo systemctl restart gdm   # re-login after this

git clone https://github.com/mmhfarooque/zombie-event-log.git
cd zombie-event-log
sudo bash install.sh
zel doctor

sudo systemctl enable --now ssh
sudo passwd ubuntu
hostname -I

# (now SSH in from laptop and start: sudo journalctl -f -k > /tmp/cycle.log &)

sleep 5 && systemctl suspend
# wait 5 minutes, wake the box, observe

# capture (from laptop SSH session):
zel last 5
sudo cp -a /var/lib/zel/cycles /tmp/mutter-evidence/
sudo journalctl -k --since "30 min ago" > /tmp/mutter-evidence/kernel.txt
```

## Reference cycles for comparison (Mahmud's hardware, KWin)

When evaluating the captured mutter data, compare against the KWin baseline from `PROJECT_LOG.md`:

- **C1** `20260502-153242` — 98-min nap, 61,758 render failures, 172-second storm, **rescued/high**
- **C2** `20260503-135828` — 109-second nap, 0 render failures (kernel-level only), **rescued/high**
- **C3** `20260503-142615` — 95-min nap, 24 render failures, **rescued/high**

If mutter on the same hardware produces `outcome=catastrophic` for any nap length where KWin produced `rescued`, that's the publishable finding.
