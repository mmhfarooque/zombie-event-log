# Muffin (Cinnamon / Linux Mint) adapter — v0.1 stub.
#
# Muffin is a mutter fork; signals are similar but log namespaces differ.
# Status: PARTIAL — needs ground truth from real Mint resume failures.

zel_adapter_muffin() {
    local journal="$1"

    local kms_fail muffin_err drm_err
    kms_fail=$(echo "$journal"   | grep -c "muffin.*kms\|MetaKms.*failed" || true)
    muffin_err=$(echo "$journal" | grep -c "muffin.*ERROR" || true)
    drm_err=$(echo "$journal"    | grep -c "drm.*atomic.*-EINVAL" || true)

    echo "muffin_kms_failures=$kms_fail"
    echo "muffin_errors=$muffin_err"
    echo "muffin_drm_errors=$drm_err"

    if [ "$kms_fail" -eq 0 ] && [ "$muffin_err" -eq 0 ] && [ "$drm_err" -eq 0 ]; then
        echo "outcome=clean"
        echo "outcome_confidence=medium"
    else
        echo "outcome=catastrophic"
        echo "outcome_confidence=low"
        echo "note=muffin_adapter_v0.1_partial"
    fi
}
