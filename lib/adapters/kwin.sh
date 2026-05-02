# KWin adapter — reads a journal slice, emits classification key=value lines.
#
# Signal model (validated against KDE Plasma 6 on Wayland with NVIDIA 595.58.03-open):
#   - "Atomic modeset test failed!" repeats while DRM is dead. KWin retries.
#   - "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT" cascade in kwin_scene_opengl.
#   - Recovery signal: a successful render after the failure storm — easiest proxy
#     is the *last* "Atomic modeset test failed!" appearing well before the journal
#     ends, with no further ones in the tail.

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

    # Heuristic outcome:
    #   clean         — no failures recorded
    #   rescued       — failures present, but a clear gap between the last failure
    #                   and the end of the journal slice (compositor recovered)
    #   catastrophic  — failures present and ongoing into the tail of the slice
    if [ "$atomic_fail" -eq 0 ] && [ "$fb_incomplete" -eq 0 ] && [ "$output_failed" -eq 0 ]; then
        echo "outcome=clean"
        echo "outcome_confidence=high"
        return
    fi

    # Find timestamp of last atomic-modeset failure vs end of slice.
    local last_fail_line
    last_fail_line=$(echo "$journal" | grep -n "Atomic modeset test failed" | tail -1 | cut -d: -f1)
    local total_lines
    total_lines=$(echo "$journal" | wc -l)

    if [ -z "$last_fail_line" ] || [ -z "$total_lines" ] || [ "$total_lines" -eq 0 ]; then
        echo "outcome=catastrophic"
        echo "outcome_confidence=low"
        return
    fi

    local tail_gap=$((total_lines - last_fail_line))
    echo "kwin_tail_gap_lines=$tail_gap"

    # If the final 25% of the slice is failure-free, we likely recovered.
    local quarter=$((total_lines / 4))
    [ "$quarter" -lt 50 ] && quarter=50
    if [ "$tail_gap" -gt "$quarter" ]; then
        echo "outcome=rescued"
        echo "outcome_confidence=medium"
    else
        echo "outcome=catastrophic"
        echo "outcome_confidence=medium"
    fi
}
