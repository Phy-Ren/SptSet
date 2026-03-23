#!/bin/bash
# monitor.sh - SptSet Space Group Job Monitor
#
# Manages PBS job submission for systematic space group computation.
# Keeps cluster busy while maintaining high Maui fair-share priority.
#
# Strategy:
#   - HARDEST SGs (210/219/228) + their fix variants: extended queue only
#   - ALL other SGs: long queue (336h=14 days, all nodes, no MAXPROC limit)
#   - extended has MAXPROC=168 (6 nodes max) — reserved for 6 hardest jobs
#   - Control long queue depth to avoid Maui fair-share penalty
#   - NEVER touch hardest SGs (210/219/228) or their fix variants
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
# This also protects "fix" variants (sg210fix etc.) — see sg_number_from_name()
HARDEST="210 219 228"
SKIP="1"

# Extract SG number from PBS job name. Strips "sg" prefix, leading zeros, AND "fix" suffix.
# e.g. "sg210" -> "210", "sg210fix" -> "210", "sg088" -> "88"
sg_number_from_name() {
    echo "$1" | sed 's/^sg0*//;s/fix$//'
}

# How many IDLE long-queue jobs to maintain (drip-feed to avoid fair-share penalty)
# extended is reserved for HARDEST only — no non-hardest extended submissions
# long walltime (336h) is much less toxic to fair-share than extended (4320h),
# so we can afford more queued jobs. 6 covers typical checkpoint resubmissions.
TARGET_IDLE_LONG=6

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
    # Pattern-matched errors (ModRat, Resolution)
    (grep -rl "Resolution3DSpaceGroup" "$BASE/results/" 2>/dev/null; \
     grep -rl "ModRat" "$BASE/results/" 2>/dev/null) | \
        sed -n 's/.*sg0*\([0-9]*\)\..*/\1/p' | sort -nu || true
    # Generic crash: GAP exited (has "Exit:" line) but didn't complete ("ALL DONE")
    for f in "$BASE/results"/sg*.log "$BASE/results"/sg*.out; do
        [ -f "$f" ] || continue
        grep -q "^=== Exit:" "$f" 2>/dev/null || continue
        grep -q "ALL DONE" "$f" 2>/dev/null && continue
        sed -n 's/.*sg0*\([0-9]*\)\..*/\1/p' <<< "$f"
    done
}

# Check if a specific SG's job crashed (GAP exited on its own without completing).
# Returns 0 (true) if the job crashed and should NOT be resubmitted.
# Returns 1 (false) if safe to resubmit (walltime kill or no log).
sg_crashed() {
    local sg=$1 p logfile
    p=$(printf '%03d' "$sg")
    for logfile in "$BASE/results/sg${p}.log" "$BASE/results/sg${p}.out"; do
        [ -f "$logfile" ] || continue
        if grep -q "^=== Exit:" "$logfile" 2>/dev/null; then
            if ! grep -q "ALL DONE" "$logfile" 2>/dev/null; then
                return 0
            fi
        fi
    done
    return 1
}

# Parse qstat. Sets: PBS_LIST, RUN_L, IDLE_L, RUN_E, IDLE_E
parse_pbs() {
    PBS_LIST=""
    RUN_L=0; IDLE_L=0; RUN_E=0; IDLE_E=0
    local qstat
    qstat=$(ssh "$HEAD" 'qstat -a' 2>/dev/null | grep xyren || true)
    [ -z "$qstat" ] && return
    while IFS= read -r line; do
        local name queue state sg
        name=$(echo "$line" | awk '{print $4}')
        queue=$(echo "$line" | awk '{print $3}')
        state=$(echo "$line" | awk '{print $10}')
        sg=$(sg_number_from_name "$name")
        [ -z "$sg" ] && continue
        [ "$state" = "C" ] && continue
        PBS_LIST="$PBS_LIST $sg"
        if [ "$state" = "R" ]; then
            case "$queue" in
                long)     ((RUN_L++)) || true ;;
                extended) ((RUN_E++)) || true ;;
                bigmem)   ((RUN_L++)) || true ;;
            esac
        else
            case "$queue" in
                long)     ((IDLE_L++)) || true ;;
                extended) ((IDLE_E++)) || true ;;
                bigmem)   ((IDLE_L++)) || true ;;
            esac
        fi
    done <<< "$qstat"
}

# Cancel queued jobs for SGs that are already completed or errored (zombie jobs)
cancel_stale_jobs() {
    local done_err="$1"
    [ -z "$done_err" ] && return
    local qstat stale_found=false
    qstat=$(ssh "$HEAD" 'qstat -a' 2>/dev/null | grep xyren || true)
    [ -z "$qstat" ] && return
    while IFS= read -r line; do
        local jobid name state sg
        jobid=$(echo "$line" | awk '{print $1}' | sed 's/\..*//')
        name=$(echo "$line" | awk '{print $4}')
        state=$(echo "$line" | awk '{print $10}')
        sg=$(sg_number_from_name "$name")
        [ "$state" = "R" ] && continue
        [ "$state" = "C" ] && continue
        contains "$sg" $HARDEST && continue
        if contains "$sg" $done_err; then
            if $DRY_RUN; then
                info "  [DRY-RUN] Would cancel stale SG#$sg ($jobid) - already done/errored"
            else
                ssh -n "$HEAD" "qdel $jobid" 2>/dev/null || true
                info "  CANCEL stale SG#$sg ($jobid) - already done/errored"
                stale_found=true
            fi
        fi
    done <<< "$qstat"
    if $stale_found; then
        sleep 2
        parse_pbs
    fi
}

# Cancel EXCESS non-hardest idle long jobs (keep at most TARGET_IDLE_LONG)
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
        sg=$(sg_number_from_name "$name")
        [ "$state" = "R" ] && continue
        [ "$state" = "C" ] && continue
        contains "$sg" $HARDEST && continue
        # Count queued jobs in long (or legacy bigmem)
        case "$queue" in long|bigmem) ;; *) continue ;; esac
        ((count++)) || true
        if [ "$count" -gt "$TARGET_IDLE_LONG" ]; then
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
    info "  PBS: R=${RUN_L}L+${RUN_E}E | idle=${IDLE_L}L+${IDLE_E}E"

    local EXCLUDE="$DONE $ERR $PBS_LIST"

    # 0. Cancel stale jobs: queued jobs for already completed/errored SGs
    cancel_stale_jobs "$DONE $ERR"

    # 1. Cancel excess non-hardest idle long jobs (if > TARGET)
    if [ "$IDLE_L" -gt "$TARGET_IDLE_LONG" ]; then
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

    # 3. Fill long queue (all non-hardest SGs go here)
    local need=$((TARGET_IDLE_LONG - IDLE_L))
    while [ "$need" -gt 0 ]; do
        local sg
        sg=$(next_sg "$EXCLUDE") || true
        [ -z "$sg" ] && break
        submit "$sg" "long"
        EXCLUDE="$EXCLUDE $sg"
        ((need--))
    done

    # 4. Resubmit expired/interrupted jobs (only walltime kills, NOT bug crashes)
    #    Use long for non-hardest (14 days is enough for most SGs)
    if ls "$CKPT_DIR"/sg*.ws >/dev/null 2>&1; then
        for ws in "$CKPT_DIR"/sg*.ws; do
            local sg
            sg=$(basename "$ws" .ws | sed 's/^sg//')
            contains "$sg" $DONE $EXCLUDE $SKIP $ERR && continue
            contains "$sg" $HARDEST && continue
            if sg_crashed "$sg"; then
                info "  SKIP SG#$sg — crashed (bug), will not resubmit"
                continue
            fi
            info "  EXPIRED SG#$sg (has checkpoint, not running) -> long"
            submit "$sg" "long"
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
    echo "PBS: Running ${RUN_L}L+${RUN_E}E | Idle ${IDLE_L}L+${IDLE_E}E"
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
