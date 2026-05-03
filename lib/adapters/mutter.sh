# Mutter (GNOME Shell) adapter — v0.1 stub, v0.2 contract.
#
# Status: PARTIAL. The signals below are observed but the rescue-vs-catastrophic
# discrimination is less reliable than KWin because mutter logs less verbosely
# during failed resumes. Contributions welcome — see docs/SUPPORTED-DESKTOPS.md.
#
# v0.2: outcome/confidence is now derived in core.sh from storm_silence_seconds.
# Adapter only emits raw counts and first/last failure timestamps.

zel_adapter_mutter() {
    local journal="$1"

    local kms_fail page_flip_fail drm_atomic_err
    kms_fail=$(echo "$journal"      | grep -c "meta-kms.*ERROR\|MetaKms.*failed" || true)
    page_flip_fail=$(echo "$journal" | grep -c "page flip\|pageflip.*failed" || true)
    drm_atomic_err=$(echo "$journal" | grep -c "drm.*atomic.*-EINVAL\|atomic_check failed" || true)

    echo "mutter_kms_failures=$kms_fail"
    echo "mutter_page_flip_failures=$page_flip_fail"
    echo "mutter_drm_atomic_errors=$drm_atomic_err"

    local mutter_pat="meta-kms.*ERROR|MetaKms.*failed|page flip|pageflip.*failed|drm.*atomic.*-EINVAL|atomic_check failed"
    local first_ts last_ts
    first_ts=$(echo "$journal" | grep -E "$mutter_pat" | head -1 | awk '{print $1, $2, $3}')
    last_ts=$(echo "$journal"  | grep -E "$mutter_pat" | tail -1 | awk '{print $1, $2, $3}')
    [ -n "$first_ts" ] && echo "mutter_first_failure_at=$first_ts"
    [ -n "$last_ts" ]  && echo "mutter_last_failure_at=$last_ts"

    [ "$kms_fail" -gt 0 ] || [ "$page_flip_fail" -gt 0 ] || [ "$drm_atomic_err" -gt 0 ] && \
        echo "note=mutter_adapter_v0.1_partial"
}
