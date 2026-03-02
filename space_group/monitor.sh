#!/bin/bash
# monitor.sh - SptSet Space Group Job Monitor
#
# Manages PBS job submission for systematic space group computation.
# Keeps cluster busy while maintaining high Maui fair-share priority.
#
# Strategy:
#   - ALL jobs use extended queue (INFINITY walltime, no interruptions)
#   - bigmem queue only for utilizing bigmem nodes (PBS/Maui limitation)
#   - Control queue depth to avoid Maui fair-share penalty
#   - NEVER touch hardest SGs (210/219/228) - they are sacred
#
# Usage:
#   ./monitor.sh              One monitoring cycle (for cron)
#   ./monitor.sh --status     Current status overview
#   ./monitor.sh --dry-run    Preview without making changes
#   ./monitor.sh --cron       Install 5-minute cron job

set -euo pipefail

BASE="/home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group"
LOGFILE="$BASE/monitor.log"
LOCKFILE="/tmp/sptset_monitor.lock"
CKPT_DIR="$HOME/checkpoints"
HEAD="head"
QSUB_CMD="cd ~/software/gap-4.13.1/pkg/SptSet && qsub"

# HARDEST SGs: ABSOLUTELY NEVER cancel, NEVER delete checkpoint, NEVER modify
HARDEST="210 219 228"
SKIP="1"

# How many IDLE jobs to maintain per queue type
# Keep extended low to avoid Maui fair-share penalty (INFINITY walltime!)
TARGET_IDLE_BIGMEM=2
TARGET_IDLE_EXTENDED=1

DRY_RUN=false

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"; }
info() { echo "$*"; log "$*"; }

contains() {
    local v="$1"; shift
    echo " $* " | grep -qw "$v" 2>/dev/null
}

completed_sgs() {
    grep -rl "ALL DONE" "$BASE/results/" 2>/dev/null | \
        sed -n 's/.*sg0*\([0-9]*\)\..*/\1/p' | sort -nu || true
}

errored_sgs() {
    (grep -rl "Resolution3DSpaceGroup" "$BASE/results/" 2>/dev/null; \
     grep -rl "ModRat" "$BASE/results/" 2>/dev/null) | \
        sed -n 's/.*sg0*\([0-9]*\)\..*/\1/p' | sort -nu || true
}

# Parse qstat. Sets: PBS_LIST, RUN_B, IDLE_B, RUN_E, IDLE_E, IDLE_E_OTHER
parse_pbs() {
    PBS_LIST=""
    RUN_B=0; IDLE_B=0; RUN_E=0; IDLE_E=0; IDLE_E_OTHER=0
    local qstat
    qstat=$(ssh "$HEAD" 'qstat -a' 2>/dev/null | grep xyren || true)
    [ -z "$qstat" ] && return
    while IFS= read -r line; do
        local name queue state sg
        name=$(echo "$line" | awk '{print $4}')
        queue=$(echo "$line" | awk '{print $3}')
        state=$(echo "$line" | awk '{print $10}')
        sg=$(echo "$name" | sed 's/^sg0*//')
        [ -z "$sg" ] && continue
        [ "$state" = "C" ] && continue
        PBS_LIST="$PBS_LIST $sg"
        if [ "$state" = "R" ]; then
            case "$queue" in
                bigmem)   ((RUN_B++)) || true ;;
                extended) ((RUN_E++)) || true ;;
            esac
        else
            case "$queue" in
                bigmem)   ((IDLE_B++)) || true ;;
                extended)
                    ((IDLE_E++)) || true
                    if ! contains "$sg" $HARDEST; then
                        ((IDLE_E_OTHER++)) || true
                    fi
                    ;;
            esac
        fi
    done <<< "$qstat"
}

# Cancel EXCESS non-hardest extended idle jobs (keep at most TARGET_IDLE_EXTENDED)
cleanup_excess() {
    local qstat count=0
    qstat=$(ssh "$HEAD" 'qstat -a' 2>/dev/null | grep xyren || true)
    [ -z "$qstat" ] && return
    while IFS= read -r line; do
        local jobid name queue state sg
        jobid=$(echo "$line" | awk '{print $1}' | sed 's/\..*//')
        name=$(echo "$line" | awk '{print $4}')
        queue=$(echo "$line" | awk '{print $3}')
        state=$(echo "$line" | awk '{print $10}')
        sg=$(echo "$name" | sed 's/^sg0*//')
        [ "$state" = "R" ] && continue
        [ "$state" = "C" ] && continue
        [ "$queue" != "extended" ] && continue
        contains "$sg" $HARDEST && continue
        ((count++)) || true
        if [ "$count" -gt "$TARGET_IDLE_EXTENDED" ]; then
            if $DRY_RUN; then
                info "  [DRY-RUN] Would cancel excess SG#$sg ($jobid)"
            else
                ssh -n "$HEAD" "qdel $jobid" 2>/dev/null || true
                info "  CANCEL excess SG#$sg ($jobid)"
            fi
        fi
    done <<< "$qstat"
}

submit() {
    local sg=$1 queue=$2
    local p
    p=$(printf '%03d' "$sg")
    (cd "$BASE" && python3 generate_batch.py "$sg" "$sg" "$queue") >/dev/null 2>&1
    if $DRY_RUN; then
        info "  [DRY-RUN] Would submit SG#$sg -> $queue"
        return
    fi
    local result
    result=$(ssh "$HEAD" "$QSUB_CMD space_group/pbs/sg${p}.sh" 2>&1)
    info "  SUBMIT SG#$sg -> $queue ($result)"
}

next_sg() {
    local exclude="$1"
    for n in $(seq 2 230); do
        contains "$n" $SKIP $HARDEST $exclude && continue
        echo "$n"
        return
    done
}

do_monitor() {
    exec 200>"$LOCKFILE"
    flock -n 200 || { echo "Another monitor instance running."; exit 0; }

    info "=== Monitor cycle ==="

    local DONE ERR
    DONE=$(completed_sgs)
    ERR=$(errored_sgs)
    parse_pbs

    info "  Completed: $(echo $DONE | wc -w) | Errors: $(echo $ERR | wc -w)"
    info "  PBS: R=${RUN_B}B+${RUN_E}E | idle=${IDLE_B}B+${IDLE_E}E (${IDLE_E_OTHER} non-hardest)"

    local EXCLUDE="$DONE $ERR $PBS_LIST"

    # 1. Cancel excess non-hardest extended idle (if > TARGET)
    if [ "$IDLE_E_OTHER" -gt "$TARGET_IDLE_EXTENDED" ]; then
        cleanup_excess
        sleep 2
        parse_pbs
        EXCLUDE="$DONE $ERR $PBS_LIST"
    fi

    # 2. Ensure HARDEST SGs are submitted (NEVER cancel these)
    for sg in $HARDEST; do
        contains "$sg" $DONE && continue
        contains "$sg" $PBS_LIST && continue
        info "  HARDEST SG#$sg not in PBS, submitting to extended"
        submit "$sg" "extended"
        EXCLUDE="$EXCLUDE $sg"
    done

    # 3. Fill bigmem queue
    local need=$((TARGET_IDLE_BIGMEM - IDLE_B))
    while [ "$need" -gt 0 ]; do
        local sg
        sg=$(next_sg "$EXCLUDE") || true
        [ -z "$sg" ] && break
        submit "$sg" "bigmem"
        EXCLUDE="$EXCLUDE $sg"
        ((need--))
    done

    # 4. Fill extended queue (non-hardest, drip-feed)
    need=$((TARGET_IDLE_EXTENDED - IDLE_E_OTHER))
    while [ "$need" -gt 0 ]; do
        local sg
        sg=$(next_sg "$EXCLUDE") || true
        [ -z "$sg" ] && break
        submit "$sg" "extended"
        EXCLUDE="$EXCLUDE $sg"
        ((need--))
    done

    # 5. Resubmit expired/interrupted jobs
    if ls "$CKPT_DIR"/sg*.ws >/dev/null 2>&1; then
        for ws in "$CKPT_DIR"/sg*.ws; do
            local sg
            sg=$(basename "$ws" .ws | sed 's/^sg//')
            contains "$sg" $DONE $EXCLUDE $SKIP $ERR && continue
            # HARDEST: always resubmit to extended (should already be there)
            contains "$sg" $HARDEST && continue
            info "  EXPIRED SG#$sg (has checkpoint, not running)"
            if [ $((RUN_B + IDLE_B)) -lt 6 ]; then
                submit "$sg" "bigmem"
            else
                submit "$sg" "extended"
            fi
            EXCLUDE="$EXCLUDE $sg"
        done
    fi

    # 6. Clean checkpoints for completed SGs (NEVER touch HARDEST!)
    for sg in $DONE; do
        contains "$sg" $HARDEST && continue
        local ws="$CKPT_DIR/sg${sg}.ws"
        if [ -f "$ws" ]; then
            if $DRY_RUN; then
                info "  [DRY-RUN] Would clean checkpoint sg${sg}.ws"
            else
                rm -f "$ws"
                info "  Cleaned checkpoint sg${sg}.ws"
            fi
        fi
    done

    info "=== Done ==="
}

do_status() {
    echo "===== SptSet Space Group Monitor ====="
    echo ""
    local DONE ERR
    DONE=$(completed_sgs)
    ERR=$(errored_sgs)
    parse_pbs
    local n_done n_err n_total
    n_done=$(echo $DONE | wc -w)
    n_err=$(echo $ERR | wc -w)
    n_total=$((n_done + n_err))
    echo "Progress: $n_total/230 ($(( n_total * 100 / 230 ))%)"
    echo "Completed ($n_done): ${DONE:-none}"
    echo "Errored   ($n_err): ${ERR:-none}"
    echo ""
    echo "PBS: Running ${RUN_B}B+${RUN_E}E | Idle ${IDLE_B}B+${IDLE_E}E (${IDLE_E_OTHER} non-hardest ext)"
    echo ""
    echo "HARDEST (210/219/228) - PROTECTED:"
    for sg in $HARDEST; do
        local status="not submitted"
        echo "$PBS_LIST" | grep -qw "$sg" && status="in PBS"
        echo "$DONE" | grep -qw "$sg" && status="COMPLETED"
        local ws="$CKPT_DIR/sg${sg}.ws"
        local ckpt="no checkpoint"
        [ -f "$ws" ] && ckpt="$(ls -lh "$ws" | awk '{print $5, $6, $7, $8}')"
        echo "  SG#$sg: $status | $ckpt"
    done
    echo ""
    ssh "$HEAD" 'qstat -a' 2>/dev/null | grep -E 'Job ID|-----|xyren' || true
    echo ""
    echo "Checkpoints:"
    ls -lh "$CKPT_DIR"/sg*.ws 2>/dev/null || echo "  (none)"
}

do_cron() {
    local script
    script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    local line="*/5 * * * * $script >> $LOGFILE 2>&1"
    if crontab -l 2>/dev/null | grep -qF "monitor.sh"; then
        echo "Cron already installed:"
        crontab -l | grep monitor
    else
        (crontab -l 2>/dev/null || true; echo "$line") | crontab -
        echo "Installed: $line"
    fi
}

case "${1:-}" in
    --status)   do_status ;;
    --cron)     do_cron ;;
    --dry-run)  DRY_RUN=true; do_monitor ;;
    --help|-h)
        echo "Usage: $(basename $0) [--status|--cron|--dry-run|--help]"
        echo "  (no args)   Run one monitor cycle"
        echo "  --status    Show current status"
        echo "  --dry-run   Preview what would be done"
        echo "  --cron      Install cron job (every 5 min)"
        ;;
    *)          do_monitor ;;
esac
