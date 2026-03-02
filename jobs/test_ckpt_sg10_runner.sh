#!/bin/bash
# Checkpoint Thorough Test — Runner Script
#
# Phase 1: Run full computation with per-step checkpoint saves
# Phase 2: Verify resume from EVERY checkpoint
#
# Usage:
#   bash test_ckpt_sg10_runner.sh [PARALLEL_JOBS]
#
# Examples:
#   bash test_ckpt_sg10_runner.sh 0    # sequential (slowest, purest test)
#   bash test_ckpt_sg10_runner.sh 8    # 8 parallel workers (cluster3)
#   bash test_ckpt_sg10_runner.sh 24   # 24 parallel workers (compute node)
#
# Expected time:
#   cluster3 seq:    ~3-5h Phase1 + ~3-5h Phase2
#   cluster3 par=8:  ~1-2h Phase1 + ~1-2h Phase2
#   compute node:    ~1h Phase1 + ~1h Phase2

set -e

JOBS="${1:-0}"
HOSTNAME_SHORT="$(hostname | cut -d. -f1)"
GAP="${HOME}/software/gap-4.13.1/gap"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CKPT_DIR="${HOME}/checkpoints/test_sg10_${HOSTNAME_SHORT}"
LOG_DIR="${CKPT_DIR}/logs"

# Detect environment
if [ -n "$LD_LIBRARY_PATH" ] && echo "$LD_LIBRARY_PATH" | grep -q "gap-centos6"; then
    echo "[INFO] Running on compute node (centos6 libs detected)"
elif [ -f /etc/lsb-release ]; then
    echo "[INFO] Running on cluster3 (Ubuntu)"
else
    echo "[INFO] Unknown environment"
fi

mkdir -p "$CKPT_DIR" "$LOG_DIR"

echo "============================================================"
echo "SG #10 Checkpoint Thorough Test"
echo "  PARALLEL_JOBS: $JOBS"
echo "  GAP: $GAP"
echo "  Checkpoint dir: $CKPT_DIR"
echo "  Date: $(date)"
echo "============================================================"

# ---- Phase 1: Full computation with per-step saves ----
echo ""
echo "==== PHASE 1: Full computation with per-step checkpoint saves ===="
echo ""

EXAMPLES_DIR="${HOME}/software/gap-4.13.1/pkg/SptSet/examples"
SETUP="SPTSET_PARALLEL_JOBS := ${JOBS};; SPTSET_PARALLEL_THRESHOLD := 10;; SPTSET_PHASE2_ENABLED := true;;"

# Write a small setup file
cat > "${CKPT_DIR}/setup_test.g" << EOF
${SETUP}
CKPT_TEST_DIR := "${CKPT_DIR}";;
Read("${SCRIPT_DIR}/test_ckpt_sg10_save.g");;
EOF

echo "[Phase 1] Starting full computation..."
cd "$EXAMPLES_DIR"
"$GAP" -q -r -b "${CKPT_DIR}/setup_test.g" 2>&1 | tee "${LOG_DIR}/phase1.log"
echo "[Phase 1] Done."

# Check reference file exists
if [ ! -f "${CKPT_DIR}/reference.txt" ]; then
    echo "[ERROR] reference.txt not found. Phase 1 failed."
    exit 1
fi

# List checkpoint files
echo ""
echo "Checkpoint files created:"
ls -lh "${CKPT_DIR}"/step_*.ws 2>/dev/null || echo "  (none found - error!)"
echo ""

# ---- Phase 2: Verify resume from each checkpoint ----
echo ""
echo "==== PHASE 2: Verify resume from every checkpoint ===="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

for wsfile in $(ls "${CKPT_DIR}"/step_*.ws 2>/dev/null | sort); do
    stepname=$(basename "$wsfile" .ws)
    TOTAL=$((TOTAL + 1))
    echo "--- Testing resume from ${stepname} ---"

    # Write setup for this verify run
    cat > "${CKPT_DIR}/setup_verify.g" << EOF2
${SETUP}
CKPT_TEST_DIR := "${CKPT_DIR}";;
Read("${SCRIPT_DIR}/test_ckpt_sg10_verify.g");;
EOF2

    if (cd "$EXAMPLES_DIR" && "$GAP" -q -r -L "$wsfile" -b "${CKPT_DIR}/setup_verify.g") 2>&1 | tee "${LOG_DIR}/verify_${stepname}.log" | grep -q "ALL PASS"; then
        echo "  => ${stepname}: PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  => ${stepname}: *** FAIL ***"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
done

# ---- Summary ----
echo "============================================================"
echo "CHECKPOINT TEST SUMMARY"
echo "============================================================"
echo "  Total checkpoints tested: ${TOTAL}"
echo "  Passed: ${PASS_COUNT}"
echo "  Failed: ${FAIL_COUNT}"
echo ""
if [ "$FAIL_COUNT" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
    echo "  *** ALL TESTS PASSED ***"
else
    echo "  *** SOME TESTS FAILED ***"
fi
echo ""
echo "  Logs in: ${LOG_DIR}/"
echo "  Date: $(date)"
echo "============================================================"
