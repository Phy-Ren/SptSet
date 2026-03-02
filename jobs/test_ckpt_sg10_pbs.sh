#!/bin/csh
#PBS -S /bin/csh
#PBS -q normal
#PBS -l nodes=1:ppn=28
#PBS -N ckpt_test
#PBS -o /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/ckpt_test.out
#PBS -e /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/ckpt_test.err

# Checkpoint thorough test on compute node
# Runs the full test_ckpt_sg10_runner.sh with 24 parallel workers

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

echo "=== Checkpoint Test on Compute Node ==="
echo "Host: `hostname`"
echo "Date: `date`"
echo "Cores: 28"
echo "Workers: 24"

# Use bash for the runner script
/bin/bash /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/test_ckpt_sg10_runner.sh 24

echo "=== Exit: $status ==="
echo "=== End: `date` ==="
