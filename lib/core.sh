# zel core library — shared helpers, journal slicing, classification dispatch.
#
# Sourced by bin/zel. Not executable on its own.

ZEL_DATA_DIR="${ZEL_DATA_DIR:-/var/lib/zel}"
ZEL_CYCLES_DIR="${ZEL_DATA_DIR}/cycles"
ZEL_LIB_DIR="${ZEL_LIB_DIR:-/usr/local/share/zel/lib}"
ZEL_VERSION="0.1.0"

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

# Pull the journal slice covering a cycle. Bounded by suspend_at..resume_at+grace.
zel_journal_slice() {
    local cycle_file="$1" grace_seconds="${2:-120}"
    local suspend_epoch resume_epoch
    suspend_epoch=$(zel_field "$cycle_file" suspend_at_epoch)
    resume_epoch=$(zel_field "$cycle_file" resume_at_epoch)

    [ -z "$suspend_epoch" ] || [ "$suspend_epoch" = "null" ] && suspend_epoch=$(zel_field "$cycle_file" resume_at_epoch)
    [ -z "$resume_epoch" ] || [ "$resume_epoch" = "null" ] && resume_epoch=$(date +%s)

    local since="@$suspend_epoch"
    local until_ts=$((resume_epoch + grace_seconds))
    journalctl --since="$since" --until="@$until_ts" --no-pager 2>/dev/null
}

# Dispatch to the per-compositor adapter. Returns key=value lines on stdout.
zel_classify() {
    local cycle_file="$1"
    local compositor journal
    compositor=$(zel_field "$cycle_file" compositor)
    journal=$(zel_journal_slice "$cycle_file")

    # Universal signals (compositor-agnostic)
    local gsp_count drm_open_fail
    gsp_count=$(echo "$journal" | grep -c "_kgspIsHeartbeatTimedOut\|GSP RM heartbeat timed out" || true)
    drm_open_fail=$(echo "$journal" | grep -c "Failed to open drm device\|Failed to open /dev/dri" || true)

    echo "compositor=$compositor"
    echo "gsp_heartbeat_timeouts=$gsp_count"
    echo "drm_open_failures=$drm_open_fail"

    case "$compositor" in
        kwin_wayland|kwin_x11)
            source "$ZEL_LIB_DIR/adapters/kwin.sh"
            zel_adapter_kwin "$journal"
            ;;
        gnome-shell)
            source "$ZEL_LIB_DIR/adapters/mutter.sh"
            zel_adapter_mutter "$journal"
            ;;
        cinnamon)
            source "$ZEL_LIB_DIR/adapters/muffin.sh"
            zel_adapter_muffin "$journal"
            ;;
        *)
            echo "outcome=unknown_compositor"
            echo "outcome_confidence=low"
            echo "note=no_adapter_for_$compositor"
            ;;
    esac
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
    [ -d "$ZEL_CYCLES_DIR" ] && echo "$ZEL_CYCLES_DIR ($(ls "$ZEL_CYCLES_DIR" 2>/dev/null | wc -l) cycles)" || echo "missing"
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
}

zel_list() {
    zel_check_data_dir
    ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.json$//' | sort
}

zel_last() {
    zel_check_data_dir
    local n="${1:-5}"
    local files
    files=$(ls -1t "$ZEL_CYCLES_DIR"/*.json 2>/dev/null | head -"$n")
    [ -z "$files" ] && { echo "no cycles recorded yet"; return; }
    printf '%-22s  %-15s  %-8s  %-13s  %s\n' "CYCLE_ID" "COMPOSITOR" "LOCKED" "OUTCOME" "GSP"
    while read -r f; do
        [ -z "$f" ] && continue
        local id comp locked
        id=$(zel_field "$f" cycle_id)
        comp=$(zel_field "$f" compositor)
        locked=$(zel_field "$f" locked_at_suspend)
        local cls
        cls=$(zel_classify "$f")
        local outcome gsp
        outcome=$(echo "$cls" | grep '^outcome=' | head -1 | cut -d= -f2)
        gsp=$(echo "$cls" | grep '^gsp_heartbeat_timeouts=' | cut -d= -f2)
        printf '%-22s  %-15s  %-8s  %-13s  %s\n' "$id" "$comp" "$locked" "${outcome:-?}" "${gsp:-0}"
    done <<< "$files"
}

zel_stats() {
    zel_check_data_dir
    local total=0 clean=0 rescued=0 catastrophic=0 unknown=0 gsp_total=0
    local files
    files=$(ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null)
    [ -z "$files" ] && { echo "no cycles recorded yet"; return; }

    while read -r f; do
        [ -z "$f" ] && continue
        total=$((total + 1))
        local cls outcome gsp
        cls=$(zel_classify "$f")
        outcome=$(echo "$cls" | grep '^outcome=' | head -1 | cut -d= -f2)
        gsp=$(echo "$cls" | grep '^gsp_heartbeat_timeouts=' | cut -d= -f2)
        case "$outcome" in
            clean)        clean=$((clean + 1)) ;;
            rescued)      rescued=$((rescued + 1)) ;;
            catastrophic) catastrophic=$((catastrophic + 1)) ;;
            *)            unknown=$((unknown + 1)) ;;
        esac
        [ -n "$gsp" ] && [ "$gsp" -gt 0 ] && gsp_total=$((gsp_total + 1))
    done <<< "$files"

    echo "Zombie Event Log — summary"
    echo
    printf '  total cycles:        %d\n' "$total"
    printf '  clean (no GSP/error): %d\n' "$clean"
    printf '  rescued by compositor: %d\n' "$rescued"
    printf '  catastrophic:        %d\n' "$catastrophic"
    printf '  unclassified:        %d\n' "$unknown"
    printf '  cycles with GSP:     %d\n' "$gsp_total"
    if [ "$rescued" -gt 0 ] || [ "$catastrophic" -gt 0 ]; then
        local denom=$((rescued + catastrophic))
        local pct=$((rescued * 100 / denom))
        printf '  rescue rate:         %d%% (%d of %d non-clean cycles)\n' "$pct" "$rescued" "$denom"
    fi
}

zel_catastrophic() {
    zel_check_data_dir
    local files
    files=$(ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null)
    while read -r f; do
        [ -z "$f" ] && continue
        local cls outcome
        cls=$(zel_classify "$f")
        outcome=$(echo "$cls" | grep '^outcome=' | head -1 | cut -d= -f2)
        if [ "$outcome" = "catastrophic" ]; then
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
    zel_classify "$f"
}

zel_compare() {
    local a="${1:-}" b="${2:-}"
    [ -z "$a" ] || [ -z "$b" ] && zel_die "usage: zel compare <id1> <id2>"
    local fa="$ZEL_CYCLES_DIR/$a.json" fb="$ZEL_CYCLES_DIR/$b.json"
    [ -f "$fa" ] || zel_die "no such cycle: $a"
    [ -f "$fb" ] || zel_die "no such cycle: $b"
    local ca cb
    ca=$(zel_classify "$fa")
    cb=$(zel_classify "$fb")
    diff <(echo "$ca") <(echo "$cb") | sed -e "s|^<|$a:|" -e "s|^>|$b:|"
}

zel_export() {
    local out="${1:-}"
    [ -z "$out" ] && zel_die "usage: zel export <path.jsonl>"
    : > "$out"
    local files
    files=$(ls -1 "$ZEL_CYCLES_DIR"/*.json 2>/dev/null)
    while read -r f; do
        [ -z "$f" ] && continue
        # one JSON object per line
        tr -d '\n' < "$f" | sed 's/  */ /g' >> "$out"
        echo >> "$out"
    done <<< "$files"
    echo "wrote $(wc -l < "$out") cycles to $out"
}
