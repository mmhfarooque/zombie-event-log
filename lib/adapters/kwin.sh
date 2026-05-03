# KWin adapter — reads a journal slice, emits classification key=value lines.
#
# Signal model (validated against KDE Plasma 6 on Wayland with NVIDIA 595.58.03-open):
#   - "Atomic modeset test failed!" repeats while DRM is dead. KWin retries.
#   - "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT" cascade in kwin_scene_opengl.
#   - "kwin_scene_opengl ... GL_INVALID_OPERATION" pairs with the framebuffer
#     line 1:1 — same render attempt logged from FB stage and scene loop.
#
# v0.2: outcome/confidence is now derived in core.sh from `storm_silence_seconds`
# (universal). The adapter only emits raw counts and the first/last failure
# timestamps so the universal layer can compute storm_duration_seconds /
# render_recovery_at / outcome consistently across compositors.

zel_adapter_kwin() {
    local journal="$1"

    local atomic_fail fb_incomplete output_failed scene_errors
    atomic_fail=$(echo "$journal" | grep -c "Atomic modeset test failed" || true)
    fb_incomplete=$(echo "$journal" | grep -c "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT" || true)
    output_failed=$(echo "$journal" | grep -c "Applying output configuration failed" || true)
    scene_errors=$(echo "$journal" | grep -c "kwin_scene_opengl.*GL_INVALID_OPERATION" || true)

    echo "kwin_atomic_modeset_failures=$atomic_fail"
    echo "kwin_framebuffer_incomplete=$fb_incomplete"
    echo "kwin_output_config_failed=$output_failed"
    echo "kwin_scene_gl_errors=$scene_errors"

    # First and last failure timestamps — used by core.sh to derive
    # storm_duration_seconds and render_recovery_at.
    # Pattern unions all KWin-specific failure signatures so we capture the
    # full storm window, not just atomic-modeset retries.
    local kwin_pat="Atomic modeset test failed|GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT|Applying output configuration failed|kwin_scene_opengl.*GL_INVALID_OPERATION"
    local first_ts last_ts
    first_ts=$(echo "$journal" | grep -E "$kwin_pat" | head -1 | awk '{print $1, $2, $3}')
    last_ts=$(echo "$journal"  | grep -E "$kwin_pat" | tail -1 | awk '{print $1, $2, $3}')
    [ -n "$first_ts" ] && echo "kwin_first_failure_at=$first_ts"
    [ -n "$last_ts" ]  && echo "kwin_last_failure_at=$last_ts"

    # tail_gap_lines: kept as a diagnostic signal but no longer used for
    # outcome/confidence — universal `storm_silence_seconds` (time-based) is
    # the canonical rescue evidence in v0.2. Useful when comparing v0.1 vs
    # v0.2 verdicts on the same cycle.
    local last_fail_line total_lines tail_gap=0
    last_fail_line=$(echo "$journal" | grep -nE "$kwin_pat" | tail -1 | cut -d: -f1)
    total_lines=$(echo "$journal" | wc -l)
    if [ -n "$last_fail_line" ] && [ -n "$total_lines" ] && [ "$total_lines" -gt 0 ]; then
        tail_gap=$((total_lines - last_fail_line))
    fi
    echo "kwin_tail_gap_lines=$tail_gap"
}
