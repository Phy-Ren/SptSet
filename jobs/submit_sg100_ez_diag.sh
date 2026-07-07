#!/bin/csh
#PBS -S /bin/csh
#PBS -q long
#PBS -l nodes=1:ppn=28
#PBS -N sg100_ez_diag
#PBS -o /home/user/xyren/gap-debug/pkg/SptSet/jobs/sg100_ez_diag.out
#PBS -e /home/user/xyren/gap-debug/pkg/SptSet/jobs/sg100_ez_diag.err

# SG#100 (P4bm) EZ full diagnostic on compute node
# Debug version, 26 parallel workers, resolution depth 9
#
# Submit: ssh head "cd ~/gap-debug/pkg/SptSet/jobs && qsub submit_sg100_ez_diag.sh"

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

echo "=== SG#100 EZ Diagnostic Job ==="
echo "Host: `hostname`"
echo "Date: `date`"
echo ""

/home/user/xyren/software/gap-4.13.1/gap \
  -l "/home/user/xyren/gap-debug/;/home/user/xyren/software/gap-4.13.1/" \
  -q -r -b /home/user/xyren/gap-debug/pkg/SptSet/debug/exp_sg100_ez_diag.g

set EXIT_STATUS = $status
echo ""
echo "=== Exit: $EXIT_STATUS ==="
echo "=== End: `date` ==="
