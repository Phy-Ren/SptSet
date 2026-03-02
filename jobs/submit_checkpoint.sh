#!/bin/csh
#PBS -S /bin/csh
#PBS -q extended
#PBS -l nodes=1:ppn=28
#PBS -N sg_ckpt
#PBS -o /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/sg_ckpt.out
#PBS -e /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/sg_ckpt.err

# Checkpoint-enabled PBS job script for SptSet
#
# Usage:
#   1. Edit SETUP_SCRIPT below to point to your setup file
#   2. Submit: ssh head "cd ~/software/gap-4.13.1/pkg/SptSet/jobs && qsub submit_checkpoint.sh"
#   3. If interrupted, simply re-submit — it resumes from checkpoint automatically
#
# The setup script (e.g., setup_sg210_ckpt.g) sets:
#   CKPT_SG_NUM, SPTSET_PARALLEL_JOBS, etc.
#   Then reads checkpoint_driver.g

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

set SETUP_SCRIPT = /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/setup_sg210_ckpt.g
set GAP = /home/user/xyren/software/gap-4.13.1/gap
set SG_NUM = 210

echo "=== SptSet Checkpoint Job ==="
echo "Host: `hostname`"
echo "Date: `date`"
echo "Setup: $SETUP_SCRIPT"

set CKPT_FILE = ~/checkpoints/sg${SG_NUM}.ws

if ( -f $CKPT_FILE ) then
    echo "Checkpoint found: $CKPT_FILE"
    echo "Resuming from checkpoint..."
    $GAP -q -r -L $CKPT_FILE -b $SETUP_SCRIPT
else
    echo "No checkpoint found. Fresh start."
    $GAP -q -r -b $SETUP_SCRIPT
endif

set EXIT_STATUS = $status
echo "=== Exit: $EXIT_STATUS ==="
echo "=== End: `date` ==="
