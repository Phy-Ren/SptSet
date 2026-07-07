#!/bin/csh
#PBS -S /bin/csh
#PBS -q extended
#PBS -l nodes=1:ppn=28
#PBS -N sg106_diag_ckpt
#PBS -o /home/user/xyren/gap-debug/pkg/SptSet/jobs/sg106_diag_ckpt.out
#PBS -e /home/user/xyren/gap-debug/pkg/SptSet/jobs/sg106_diag_ckpt.err

# SG#106 EZ diagnostic WITH checkpoint — debug line, extended queue

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib
set GAP = /home/user/xyren/software/gap-4.13.1/gap
set SCRIPT = /home/user/xyren/gap-debug/pkg/SptSet/debug/exp_sg106_ez_diag_ckpt.g
set CKPT = ~/checkpoints/sg106_diag.ws
set GAPROOT = "/home/user/xyren/gap-debug/;/home/user/xyren/software/gap-4.13.1/"

echo "=== SG#106 EZ Diagnostic [CHECKPOINT] ==="
echo "Host: `hostname`"
echo "Date: `date`"

if ( -f $CKPT ) then
    echo "Resuming from checkpoint..."
    $GAP -l "$GAPROOT" -q -r -L $CKPT -b $SCRIPT
else
    echo "Fresh start..."
    $GAP -l "$GAPROOT" -q -r -b $SCRIPT
endif

echo "=== Exit: $status ==="
echo "=== End: `date` ==="
