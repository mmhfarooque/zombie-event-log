# zel core library — shared helpers, journal slicing, classification dispatch.
#
# Sourced by bin/zel. Not executable on its own.

ZEL_DATA_DIR="${ZEL_DATA_DIR:-/var/lib/zel}"
ZEL_CYCLES_DIR="${ZEL_DATA_DIR}/cycles"
ZEL_LIB_DIR="${ZEL_LIB_DIR:-/usr/local/share/zel/lib}"
# Classifier output cache. /var/lib/zel/cycles/ is root-owned (hook writes
# as root); the CLI runs as the user. We keep the cache in XDG_CACHE_HOME so
# any user can re-classify and persist without sudo. The cache is per-user
# but classifier output is reproducible from the journal, so cross-user
# divergence is fine.
ZEL_CACHE_DIR="${ZEL_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zel/classifier}"
ZEL_VERSION="0.2.0"
ZEL_SCHEMA_VERSION=2

# Adaptive journal slicing — the storm can run minutes past resume on long naps.
# We pull a wide window from suspend → resume + hard_cap, then derive the actual
# end from the data (last failure timestamp + silence). Replaces the v0.1 fixed
# `resume + 120s` window which under-reported severe cycles by ~31%.
ZEL_SLICE_HARD_CAP_SECONDS="${ZEL_SLICE_HARD_CAP_SECONDS:-1800}"   # 30 min cap
ZEL_SLICE_SILENCE_SECONDS="${ZEL_SLICE_SILENCE_SECONDS:-30}"      # storm-end gap
ZEL_SLICE_INITIAL_GRACE="${ZEL_SLICE_INITIAL_GRACE:-60}"          # min trail past resume

# Severity thresholds (gpu_render_failures count)
ZEL_SEVERITY_MODERATE_MIN=1000
ZEL_SEVERITY_SEVERE_MIN=10000

zel_die() { echo "zel: $*" >&2; exit 1; }

zel_require() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        zel_die "missing required commands: ${missing[*]} (install via your package manager)"
    fi
}

zel_check_data_dir() {
    if [ ! -d "$ZEL_CYCLES_DIR" ]; then
        zel_die "no data directory at $ZEL_CYCLES_DIR — has the systemd-sleep hook run yet? try: sudo bash $ZEL_LIB_DIR/../install.sh"
    fi
}

# Read a JSON field from a cycle file. Uses jq if present, else simple grep.
zel_field() {
    local file="$1" field="$2"
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$field // \"\"" "$file" 2>/dev/null
    else
        grep -E "\"$field\"" "$file" | head -1 | sed -E 's/.*: ?"?([^",}]*)"?,?.*/\1/'
    fi
}

# Path of the persisted classifier output for a cycle.
zel_classifier_file() {
    local cycle_id="$1"
    mkdir -p "$ZEL_CACHE_DIR" 2>/dev/null
    echo "$ZEL_CACHE_DIR/$cycle_id.classifier.json"
}

# Pull the journal slice covering a cycle. Pulls a wide window — adapters and
# universal post-signals derive the actual storm end from the data.
zel_journal_slice() {
    local cycle_file="$1" hard_cap="${2:-$ZEL_SLICE_HARD_CAP_SECONDS}"
    local suspend_epoch resume_epoch
    suspend_epoch=$(zel_field "$cycle_file" suspend_at_epoch)
    resume_epoch=$(zel_field "$cycle_file" resume_at_epoch)

    [ -z "$suspend_epoch" ] || [ "$suspend_epoch" = "null" ] && suspend_epoch=$(zel_field "$cycle_file" resume_at_epoch)
    [ -z "$resume_epoch" ] || [ "$resume_epoch" = "null" ] && resume_epoch=$(date +%s)

    local since="@$suspend_epoch"
    local until_ts=$((resume_epoch + hard_cap))
    journalctl --since="$since" --until="@$until_ts" --no-pager 2>/dev/null
}

# Parse a journal-line timestamp ("May 02 17:10:37 ms7e41 ...") to epoch.
zel_journal_ts_epoch() {
    local line="$1"
    local ts
    ts=$(echo "$line" | awk '{print $1, $2, $3}')
    [ -z "$ts" ] && { echo ""; return; }
    date -d "$ts" +%s 2>/dev/null
}

# Get the timestamp prefix ("May 02 17:10:37") of the first or last journal
# line matching the supplied grep pattern.
zel_journal_first_ts() {
    local journal="$1" pattern="$2"
    echo "$journal" | grep -E "$pattern" | head -1 | awk '{print $1, $2, $3}'
}
zel_journal_last_ts() {
    local journal="$1" pattern="$2"
    echo "$journal" | grep -E "$pattern" | tail -1 | awk '{print $1, $2, $3}'
}

# Bucket gpu_render_failures into mild / moderate / severe.
zel_severity_bucket() {
    local n="${1:-0}"
    if [ "$n" -ge "$ZEL_SEVERITY_SEVERE_MIN" ]; then echo "severe"
    elif [ "$n" -ge "$ZEL_SEVERITY_MODERATE_MIN" ]; then echo "moderate"
    else echo "mild"; fi
}

# Dispatch to the per-compositor adapter, then layer on universal derived
# signals. Outputs key=value lines on stdout.
zel_classify() {
    local cycle_file="$1"
    local cycle_id compositor journal
    cycle_id=$(zel_field "$cycle_file" cycle_id)
    compositor=$(zel_field "$cycle_file" compositor)
    journal=$(zel_journal_slice "$cycle_file")

    local resume_epoch
    resume_epoch=$(zel_field "$cycle_file" resume_at_epoch)
    [ -z "$resume_epoch" ] || [ "$resume_epoch" = "null" ] && resume_epoch=$(date +%s)
    local slice_end_ep=$((resume_epoch + ZEL_SLICE_HARD_CAP_SECONDS))

    # Universal kernel-level signals
    local gsp_count drm_open_fail
    gsp_count=$(echo "$journal" | grep -c "_kgspIsHeartbeatTimedOut\|GSP RM heartbeat timed out" || true)
    # Exclude the benign card0 probe — kwin/sddm tries to open /dev/dri/card0
    # (the simple-framebuffer boot console, not a render node) on every login
    # and resume on a hybrid-GPU box; it always fails and is not a real error.
    drm_open_fail=$(echo "$journal" | grep -E "Failed to open drm device|Failed to open /dev/dri" | grep -vcE "card0" || true)

    echo "schema_version=$ZEL_SCHEMA_VERSION"
    echo "compositor=$compositor"
    echo "slice_end_epoch=$slice_end_ep"
    echo "gsp_heartbeat_timeouts=$gsp_count"
    echo "drm_open_failures=$drm_open_fail"

    # Userspace GPU/GL context collapse — the open-module post-resume failure
    # mode: NVIDIA VRAM-restore silently fails, the kernel logs no Xid, but GL
    # clients die. Chromium/Electron GPU process exits, GL context creation
    # failures, command-buffer proxy failures. Invisible to the adapter-only
    # signals because the compositor render loop can stay quiet.
    local gpu_userspace_collapse compositor_graphics_reset
    gpu_userspace_collapse=$(echo "$journal" | grep -cE "GPU process exited unexpectedly|GPU state invalid after|CreateCommandBuffer|gl::init::CreateGLContext failed|CollectGraphicsInfo failed|Exiting GPU process due to errors during initialization" || true)
    echo "gpu_userspace_collapse=$gpu_userspace_collapse"

    # Compositor self-rescue attempt — KWin/mutter re-init after a GL reset.
    compositor_graphics_reset=$(echo "$journal" | grep -cE "graphics reset|Desktop effects were restarted|Reinitializing OpenGL" || true)
    echo "compositor_graphics_reset=$compositor_graphics_reset"

    # Boot-end correlation — did the boot this cycle lives in die uncleanly
    # (hard-reset zombie) with no successful wake afterwards? That is the
    # definitive post-resume-collapse signal. Skip the still-running current
    # boot, and skip boots whose journal has rotated away (cannot tell).
    local boot_id this_boot cur_boot unclean_boot_end=0 boot_end_epoch="" later_wakes=0
    boot_id=$(zel_field "$cycle_file" boot_id)
    if [ -n "$boot_id" ] && [ "$boot_id" != "null" ]; then
        cur_boot=$(tr -d '-' < /proc/sys/kernel/random/boot_id 2>/dev/null)
        this_boot=$(echo "$boot_id" | tr -d '-')
        local boot_lines
        boot_lines=$(journalctl -b "$boot_id" -n 3 --no-pager 2>/dev/null | wc -l)
        if [ -n "$this_boot" ] && [ "$this_boot" != "$cur_boot" ] && [ "${boot_lines:-0}" -gt 0 ]; then
            local clean_markers
            clean_markers=$(journalctl -b "$boot_id" -n 80 --no-pager 2>/dev/null | grep -ciE "Journal stopped|systemd-shutdown|Reached target.*(Power-Off|Reboot|Halt|Shutdown)" || true)
            if [ "${clean_markers:-0}" -eq 0 ]; then
                unclean_boot_end=1
                boot_end_epoch=$(journalctl -b "$boot_id" -n 1 -o short-unix --no-pager 2>/dev/null | cut -d. -f1)
                later_wakes=$(journalctl -b "$boot_id" --since "@$((resume_epoch + 60))" --no-pager 2>/dev/null | grep -ciE "Waking up from system sleep|PM: suspend exit" || true)
            fi
        fi
    fi
    echo "unclean_boot_end=$unclean_boot_end"
    [ -n "$boot_end_epoch" ] && echo "boot_end_epoch=$boot_end_epoch"
    echo "later_wakes_after_this=${later_wakes:-0}"

    # NVIDIA GSP recovery — `Finished nvidia-resume.service` after the heartbeat
    # timeout. Brackets the kernel-level GPU wedge duration (typically 1–2s
    # even on catastrophic compositor cycles, because the kernel re-inits fast
    # but the compositor takes longer to re-render).
    if [ "$gsp_count" -gt 0 ]; then
        local gsp_first_ts gsp_recovery_ts gsp_first_ep gsp_recovery_ep
        gsp_first_ts=$(zel_journal_first_ts "$journal" "_kgspIsHeartbeatTimedOut|GSP RM heartbeat timed out")
        gsp_recovery_ts=$(zel_journal_first_ts "$journal" "Finished nvidia-resume.service")
        if [ -n "$gsp_first_ts" ]; then
            gsp_first_ep=$(date -d "$gsp_first_ts" +%s 2>/dev/null)
            echo "nvidia_gsp_first_timeout_at=$gsp_first_ts"
            [ -n "$gsp_first_ep" ] && echo "nvidia_gsp_first_timeout_at_epoch=$gsp_first_ep"
        fi
        if [ -n "$gsp_recovery_ts" ]; then
            gsp_recovery_ep=$(date -d "$gsp_recovery_ts" +%s 2>/dev/null)
            echo "nvidia_gsp_recovery_at=$gsp_recovery_ts"
            [ -n "$gsp_recovery_ep" ] && echo "nvidia_gsp_recovery_at_epoch=$gsp_recovery_ep"
            if [ -n "$gsp_first_ep" ] && [ -n "$gsp_recovery_ep" ] && [ "$gsp_recovery_ep" -ge "$gsp_first_ep" ]; then
                echo "nvidia_gsp_wedge_seconds=$((gsp_recovery_ep - gsp_first_ep))"
            fi
        fi
    fi

    # Compositor adapter — captured for derived signal extraction below.
    # In v0.2 adapters emit raw counts + first/last failure timestamps only;
    # outcome/confidence is derived universally from storm_silence_seconds.
    local adapter_out="" compositor_known=1
    case "$compositor" in
        kwin_wayland|kwin_x11)
            source "$ZEL_LIB_DIR/adapters/kwin.sh"
            adapter_out=$(zel_adapter_kwin "$journal")
            ;;
        gnome-shell)
            source "$ZEL_LIB_DIR/adapters/mutter.sh"
            adapter_out=$(zel_adapter_mutter "$journal")
            ;;
        cinnamon)
            source "$ZEL_LIB_DIR/adapters/muffin.sh"
            adapter_out=$(zel_adapter_muffin "$journal")
            ;;
        *)
            compositor_known=0
            adapter_out="note=no_adapter_for_$compositor"
            ;;
    esac
    echo "$adapter_out"

    # Universal derived signals (post-adapter).
    # gpu_render_failures: rollup of framebuffer + scene_gl. KWin emits these
    # 1:1 paired (FB-stage line + scene-loop line per failed frame), so max() is
    # the right rollup — they describe the same render from two angles.
    local fb_count scene_count gpu_render_failures
    fb_count=$(echo "$adapter_out" | grep -E "_framebuffer_incomplete=" | head -1 | cut -d= -f2)
    scene_count=$(echo "$adapter_out" | grep -E "_scene_gl_errors=" | head -1 | cut -d= -f2)
    fb_count=${fb_count:-0}
    scene_count=${scene_count:-0}
    if [ "$fb_count" -ge "$scene_count" ]; then
        gpu_render_failures=$fb_count
    else
        gpu_render_failures=$scene_count
    fi
    echo "gpu_render_failures=$gpu_render_failures"

    local severity
    severity=$(zel_severity_bucket "$gpu_render_failures")
    echo "severity=$severity"

    # storm_duration_seconds and render_recovery_at: derived from adapter's
    # first/last compositor-failure timestamps. Adapter exports these as
    # `<compositor>_first_failure_at` / `<compositor>_last_failure_at` (raw
    # journal-style "May DD HH:MM:SS" strings).
    local first_ts last_ts storm_silence_seconds=""
    first_ts=$(echo "$adapter_out" | grep -E "_first_failure_at=" | head -1 | cut -d= -f2-)
    last_ts=$(echo "$adapter_out"  | grep -E "_last_failure_at="  | head -1 | cut -d= -f2-)
    if [ -n "$first_ts" ] && [ -n "$last_ts" ]; then
        local first_ep last_ep
        first_ep=$(date -d "$first_ts" +%s 2>/dev/null)
        last_ep=$(date -d "$last_ts" +%s 2>/dev/null)
        if [ -n "$first_ep" ] && [ -n "$last_ep" ] && [ "$last_ep" -ge "$first_ep" ]; then
            echo "storm_duration_seconds=$((last_ep - first_ep))"
            local recovery_ep=$((last_ep + ZEL_SLICE_SILENCE_SECONDS))
            local recovery_iso
            recovery_iso=$(date -d "@$recovery_ep" -Iseconds 2>/dev/null)
            [ -n "$recovery_iso" ] && echo "render_recovery_at=$recovery_iso"
            echo "render_recovery_at_epoch=$recovery_ep"
            # storm_silence_seconds: how long the journal was quiet between the
            # last failure and the slice end. Replaces v0.1 `tail_gap_lines` as
            # the rescue-evidence signal — measured in time, not lines.
            local silence=$((slice_end_ep - last_ep))
            [ "$silence" -lt 0 ] && silence=0
            storm_silence_seconds=$silence
            echo "storm_silence_seconds=$silence"
        fi
    elif [ "$gpu_render_failures" -eq 0 ]; then
        echo "storm_duration_seconds=0"
        storm_silence_seconds=$((slice_end_ep - resume_epoch))
        echo "storm_silence_seconds=$storm_silence_seconds"
    fi

    # Universal outcome / outcome_confidence derivation.
    # v0.2 model — replaces v0.1 KWin-specific tail_gap-based logic:
    #   compositor unknown                                    → unknown_compositor / low
    #   no errors at all                                      → clean / high
    #   errors but no compositor render storm (counts == 0)   → rescued / high
    #   storm_silence_seconds >= 60                           → rescued / high
    #   storm_silence_seconds >= 30                           → rescued / medium
    #   storm_silence_seconds <  30                           → catastrophic
    #     confidence high if silence < 5, else medium
    # drm_open_fail is dominated by benign kwin/sddm DRM-node probe failures
    # (card*/renderD12* enumeration fallback) on this hybrid-GPU box and fires
    # on clean cycles too, so it is informational only and does NOT gate the
    # outcome. The GSP heartbeat timeout is the real kernel-level wedge signal.
    local any_kernel_error=$((gsp_count))
    local outcome outcome_confidence

    # Definitive zombie: this cycle's boot died uncleanly with no later wake.
    local post_collapse=0
    if [ "$unclean_boot_end" -eq 1 ] && [ "${later_wakes:-0}" -eq 0 ]; then
        post_collapse=1
    fi

    if [ "$compositor_known" -eq 0 ]; then
        outcome="unknown_compositor"
        outcome_confidence="low"
    elif [ "$post_collapse" -eq 1 ]; then
        # Boot ended in a hard-reset zombie and this was the last resume before
        # it. The worst outcome — overrides the render/silence heuristics.
        outcome="post_resume_collapse"
        if [ "$gpu_userspace_collapse" -gt 0 ] || [ "$any_kernel_error" -gt 0 ] || [ "$gpu_render_failures" -gt 0 ]; then
            outcome_confidence="high"
        else
            outcome_confidence="medium"
        fi
    elif [ "$gpu_userspace_collapse" -gt 0 ] && [ "$gpu_render_failures" -eq 0 ]; then
        # Resume looked clean to the compositor, but userspace GL clients died —
        # the silent VRAM-restore-failure mode. Survived this boot but degraded.
        # This is the class the pre-v0.3 classifier mislabelled clean/rescued.
        outcome="degraded"
        outcome_confidence="high"
    elif [ "$gpu_render_failures" -eq 0 ] && [ "$any_kernel_error" -eq 0 ]; then
        outcome="clean"
        outcome_confidence="high"
    elif [ "$gpu_render_failures" -eq 0 ]; then
        # Kernel-level errors fired (GSP, drm_open) but compositor never logged
        # a render failure — short nap, GPU recovered before the compositor
        # noticed. Treat as rescued.
        outcome="rescued"
        outcome_confidence="high"
    elif [ -z "$storm_silence_seconds" ]; then
        outcome="rescued"
        outcome_confidence="low"
    elif [ "$storm_silence_seconds" -ge 60 ]; then
        outcome="rescued"
        outcome_confidence="high"
    elif [ "$storm_silence_seconds" -ge 30 ]; then
        outcome="rescued"
        outcome_confidence="medium"
    else
        outcome="catastrophic"
        if [ "$storm_silence_seconds" -lt 5 ]; then
            outcome_confidence="high"
        else
            outcome_confidence="medium"
        fi
    fi
    echo "outcome=$outcome"
    echo "outcome_confidence=$outcome_confidence"

    echo "classifier_run_at=$(date -Iseconds)"
    echo "classifier_run_at_epoch=$(date +%s)"
}

# Run zel_classify and persist the output as <cycle_id>.classifier.json.
# Journals rotate; persisting keeps the verdict reproducible after the slice
# ages out of the journal.
zel_classify_persist() {
    local cycle_file="$1"
    local cycle_id
    cycle_id=$(zel_field "$cycle_file" cycle_id)
    [ -z "$cycle_id" ] && { zel_classify "$cycle_file"; return; }

    local cls
    cls=$(zel_classify "$cycle_file")
    echo "$cls"

    local out
    out=$(zel_classifier_file "$cycle_id")
    {
        echo "{"
        local first=1
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local k v
            k="${line%%=*}"
            v="${line#*=}"
            [ "$first" -eq 1 ] || echo ","
            first=0
            # numeric vs string detection — integers stay unquoted
            if [[ "$v" =~ ^-?[0-9]+$ ]]; then
                printf '  "%s": %s' "$k" "$v"
            else
                # escape backslashes and quotes in the value
                local esc
                esc=$(printf '%s' "$v" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
                printf '  "%s": "%s"' "$k" "$esc"
            fi
        done <<< "$cls"
        echo
        echo "}"
    } > "$out" 2>/dev/null
    chmod 0644 "$out" 2>/dev/null || true
}

# Read persisted classifier output if present, else run + persist.
zel_classify_cached() {
    local cycle_file="$1"
    local cycle_id
    cycle_id=$(zel_field "$cycle_file" cycle_id)
    local cache
    cache=$(zel_classifier_file "$cycle_id")
    if [ -f "$cache" ] && command -v jq >/dev/null 2>&1; then
        jq -r 'to_entries[] | "\(.key)=\(.value)"' "$cache" 2>/dev/null && return
    fi
    if [ -f "$cache" ]; then
        # jq absent — fall back to simple parsing
        sed -n 's/^  "\([^"]*\)": *"\?\([^",}]*\)"\?,\?$/\1=\2/p' "$cache"
        return
    fi
    zel_classify_persist "$cycle_file"
}

# Force-rerun classifier against the journal and persist (overwrites cache).
zel_reclassify() {
    local id="${1:-}"
    [ -z "$id" ] && zel_die "usage: zel reclassify <cycle_id>"
    local f="$ZEL_CYCLES_DIR/$id.json"
    [ -f "$f" ] || zel_die "no such cycle: $id"
    rm -f "$(zel_classifier_file "$id")"
    zel_classify_persist "$f"
}

# ---------- Subcommands ----------

zel_help() {
    cat <<EOF
zel — Zombie Event Log (v$ZEL_VERSION)

Usage:
  zel stats                  Summary across all recorded cycles
  zel last [N]               Show the N most recent cycles (default 5)
  zel catastrophic           List cycles where the compositor did not recover
  zel list                   All cycle IDs
  zel show <id>              Full evidence dump for one cycle
  zel reclassify <id>        Re-run classifier and refresh the cache
  zel compare <id1> <id2>    Side-by-side classifier output
  zel export <path>          Write all cycles to a single JSONL file
  zel doctor                 Check that the hook is installed and working
  zel version                Print version
  zel help                   This message

Data:    $ZEL_CYCLES_DIR
Hook:    /usr/lib/systemd/system-sleep/50-zel
Project: https://github.com/mmhfarooque/zombie-event-log
EOF
}

zel_doctor() {
    echo "zel doctor — environment check"
    echo
    printf '  hook installed:   '
    [ -x /usr/lib/systemd/system-sleep/50-zel ] && echo "yes" || echo "no  (run install.sh)"
    printf '  data dir:         '
    [ -d "$ZEL_CYCLES_DIR" ] && echo "$ZEL_CYCLES_DIR ($(ls "$ZEL_CYCLES_DIR" 2>/dev/null | wc -l) files)" || echo "missing"
    printf '  jq present:       '
    command -v jq >/dev/null 2>&1 && echo "yes" || echo "no  (recommended; falls back to text parsing)"
    printf '  journalctl:       '
    command -v journalctl >/dev/null 2>&1 && echo "yes" || echo "MISSING — required"
    printf '  loginctl:         '
    command -v loginctl >/dev/null 2>&1 && echo "yes" || echo "MISSING — required for lock-state detection"
    printf '  current desktop:  '
    if pgrep -x kwin_wayland >/dev/null 2>&1; then echo "kwin_wayland (KDE)"
    elif pgrep -x kwin_x11   >/dev/null 2>&1; then echo "kwin_x11 (KDE on X11)"
    elif pgrep -x gnome-shell >/dev/null 2>&1; then echo "gnome-shell (GNOME)"
    elif pgrep -x cinnamon    >/dev/null 2>&1; then echo "cinnamon (Cinnamon/Mint)"
    else echo "unrecognised — check zel show <id> output"; fi
    printf '  kernel:           '; uname -r
    printf '  schema version:   '; echo "$ZEL_SCHEMA_VERSION"
}

zel_list() {
    zel_check_data_dir
    ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | grep -v '\.classifier\.json$' | xargs -n1 basename 2>/dev/null | sed 's/\.json$//' | sort
}

zel_last() {
    zel_check_data_dir
    local n="${1:-5}"
    local files
    files=$(ls -1t "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | grep -v '\.classifier\.json$' | head -"$n")
    [ -z "$files" ] && { echo "no cycles recorded yet"; return; }
    printf '%-22s  %-15s  %-8s  %-13s  %-9s  %s\n' "CYCLE_ID" "COMPOSITOR" "LOCKED" "OUTCOME" "SEVERITY" "GSP"
    while read -r f; do
        [ -z "$f" ] && continue
        local id comp locked
        id=$(zel_field "$f" cycle_id)
        comp=$(zel_field "$f" compositor)
        locked=$(zel_field "$f" locked_at_suspend)
        local cls
        cls=$(zel_classify_cached "$f")
        local outcome severity gsp
        outcome=$(echo "$cls"  | grep '^outcome='   | head -1 | cut -d= -f2)
        severity=$(echo "$cls" | grep '^severity='  | head -1 | cut -d= -f2)
        gsp=$(echo "$cls"      | grep '^gsp_heartbeat_timeouts=' | cut -d= -f2)
        printf '%-22s  %-15s  %-8s  %-13s  %-9s  %s\n' "$id" "$comp" "$locked" "${outcome:-?}" "${severity:-?}" "${gsp:-0}"
    done <<< "$files"
}

zel_stats() {
    zel_check_data_dir
    local total=0 clean=0 rescued=0 degraded=0 catastrophic=0 post_collapse=0 unknown=0 gsp_total=0
    local mild=0 moderate=0 severe=0
    local files
    files=$(ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | grep -v '\.classifier\.json$')
    [ -z "$files" ] && { echo "no cycles recorded yet"; return; }

    while read -r f; do
        [ -z "$f" ] && continue
        total=$((total + 1))
        local cls outcome severity gsp
        cls=$(zel_classify_cached "$f")
        outcome=$(echo "$cls"  | grep '^outcome='  | head -1 | cut -d= -f2)
        severity=$(echo "$cls" | grep '^severity=' | head -1 | cut -d= -f2)
        gsp=$(echo "$cls"      | grep '^gsp_heartbeat_timeouts=' | cut -d= -f2)
        case "$outcome" in
            clean)                clean=$((clean + 1)) ;;
            rescued)              rescued=$((rescued + 1)) ;;
            degraded)             degraded=$((degraded + 1)) ;;
            catastrophic)         catastrophic=$((catastrophic + 1)) ;;
            post_resume_collapse) post_collapse=$((post_collapse + 1)) ;;
            *)                    unknown=$((unknown + 1)) ;;
        esac
        case "$severity" in
            mild)     mild=$((mild + 1)) ;;
            moderate) moderate=$((moderate + 1)) ;;
            severe)   severe=$((severe + 1)) ;;
        esac
        [ -n "$gsp" ] && [ "$gsp" -gt 0 ] && gsp_total=$((gsp_total + 1))
    done <<< "$files"

    echo "Zombie Event Log — summary"
    echo
    printf '  total cycles:        %d\n' "$total"
    printf '  clean (no GSP/error): %d\n' "$clean"
    printf '  rescued by compositor: %d\n' "$rescued"
    printf '  degraded (survived, GL collapse): %d\n' "$degraded"
    printf '  catastrophic:        %d\n' "$catastrophic"
    printf '  post-resume collapse (zombie): %d\n' "$post_collapse"
    printf '  unclassified:        %d\n' "$unknown"
    printf '  cycles with GSP:     %d\n' "$gsp_total"
    local nonclean=$((rescued + degraded + catastrophic + post_collapse))
    if [ "$nonclean" -gt 0 ]; then
        local recovered=$((rescued + degraded))
        local failed=$((catastrophic + post_collapse))
        local pct=$((recovered * 100 / nonclean))
        printf '  recovery rate:       %d%% (%d recovered, %d failed, of %d non-clean)\n' "$pct" "$recovered" "$failed" "$nonclean"
    fi
    echo
    printf '  severity — mild:     %d\n' "$mild"
    printf '  severity — moderate: %d\n' "$moderate"
    printf '  severity — severe:   %d\n' "$severe"
}

zel_catastrophic() {
    zel_check_data_dir
    local files
    files=$(ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | grep -v '\.classifier\.json$')
    while read -r f; do
        [ -z "$f" ] && continue
        local cls outcome
        cls=$(zel_classify_cached "$f")
        outcome=$(echo "$cls" | grep '^outcome=' | head -1 | cut -d= -f2)
        if [ "$outcome" = "catastrophic" ] || [ "$outcome" = "post_resume_collapse" ]; then
            zel_field "$f" cycle_id
        fi
    done <<< "$files"
}

zel_show() {
    local id="${1:-}"
    [ -z "$id" ] && zel_die "usage: zel show <cycle_id>"
    local f="$ZEL_CYCLES_DIR/$id.json"
    [ -f "$f" ] || zel_die "no such cycle: $id"
    echo "=== cycle metadata ==="
    cat "$f"
    echo
    echo "=== classifier ==="
    zel_classify_persist "$f"
}

zel_compare() {
    local a="${1:-}" b="${2:-}"
    [ -z "$a" ] || [ -z "$b" ] && zel_die "usage: zel compare <id1> <id2>"
    local fa="$ZEL_CYCLES_DIR/$a.json" fb="$ZEL_CYCLES_DIR/$b.json"
    [ -f "$fa" ] || zel_die "no such cycle: $a"
    [ -f "$fb" ] || zel_die "no such cycle: $b"
    local ca cb
    ca=$(zel_classify_cached "$fa")
    cb=$(zel_classify_cached "$fb")
    diff <(echo "$ca") <(echo "$cb") | sed -e "s|^<|$a:|" -e "s|^>|$b:|"
}

zel_export() {
    local out="${1:-}"
    [ -z "$out" ] && zel_die "usage: zel export <path.jsonl>"
    : > "$out"
    local files
    files=$(ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | grep -v '\.classifier\.json$')
    while read -r f; do
        [ -z "$f" ] && continue
        # one JSON object per line
        tr -d '\n' < "$f" | sed 's/  */ /g' >> "$out"
        echo >> "$out"
    done <<< "$files"
    echo "wrote $(wc -l < "$out") cycles to $out"
}
