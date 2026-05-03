# Muffin (Cinnamon / Linux Mint) adapter — v0.1 stub, v0.2 contract.
#
# Muffin is a mutter fork; signals are similar but log namespaces differ.
# Status: PARTIAL — needs ground truth from real Mint resume failures.
#
# v0.2: outcome/confidence is now derived in core.sh from storm_silence_seconds.
# Adapter only emits raw counts and first/last failure timestamps.

zel_adapter_muffin() {
    local journal="$1"

    local kms_fail muffin_err drm_err
    kms_fail=$(echo "$journal"   | grep -c "muffin.*kms\|MetaKms.*failed" || true)
    muffin_err=$(echo "$journal" | grep -c "muffin.*ERROR" || true)
    drm_err=$(echo "$journal"    | grep -c "drm.*atomic.*-EINVAL" || true)

    echo "muffin_kms_failures=$kms_fail"
    echo "muffin_errors=$muffin_err"
    echo "muffin_drm_errors=$drm_err"

    local muffin_pat="muffin.*kms|MetaKms.*failed|muffin.*ERROR|drm.*atomic.*-EINVAL"
    local first_ts last_ts
    first_ts=$(echo "$journal" | grep -E "$muffin_pat" | head -1 | awk '{print $1, $2, $3}')
    last_ts=$(echo "$journal"  | grep -E "$muffin_pat" | tail -1 | awk '{print $1, $2, $3}')
    [ -n "$first_ts" ] && echo "muffin_first_failure_at=$first_ts"
    [ -n "$last_ts" ]  && echo "muffin_last_failure_at=$last_ts"

    [ "$kms_fail" -gt 0 ] || [ "$muffin_err" -gt 0 ] || [ "$drm_err" -gt 0 ] && \
        echo "note=muffin_adapter_v0.1_partial"
}
