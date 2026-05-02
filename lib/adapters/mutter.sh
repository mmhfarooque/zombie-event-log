# Mutter (GNOME Shell) adapter — v0.1 stub.
#
# Status: PARTIAL. The signals below are observed but the rescue-vs-catastrophic
# discrimination is less reliable than KWin because mutter logs less verbosely
# during failed resumes. Contributions welcome — see docs/SUPPORTED-DESKTOPS.md.

zel_adapter_mutter() {
    local journal="$1"

    local kms_fail page_flip_fail drm_atomic_err
    kms_fail=$(echo "$journal"      | grep -c "meta-kms.*ERROR\|MetaKms.*failed" || true)
    page_flip_fail=$(echo "$journal" | grep -c "page flip\|pageflip.*failed" || true)
    drm_atomic_err=$(echo "$journal" | grep -c "drm.*atomic.*-EINVAL\|atomic_check failed" || true)

    echo "mutter_kms_failures=$kms_fail"
    echo "mutter_page_flip_failures=$page_flip_fail"
    echo "mutter_drm_atomic_errors=$drm_atomic_err"

    if [ "$kms_fail" -eq 0 ] && [ "$page_flip_fail" -eq 0 ] && [ "$drm_atomic_err" -eq 0 ]; then
        echo "outcome=clean"
        echo "outcome_confidence=medium"
    else
        # Mutter rarely "rescues" itself the way KWin does; treat any failure as catastrophic
        # until we have better signals from real GNOME zombie events.
        echo "outcome=catastrophic"
        echo "outcome_confidence=low"
        echo "note=mutter_adapter_v0.1_partial"
    fi
}
