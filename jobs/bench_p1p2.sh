#!/bin/csh
#PBS -S /bin/csh
#PBS -q normal
#PBS -l nodes=1:ppn=28
#PBS -N sg10_p1p2
#PBS -o $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10_p1p2.out
#PBS -e $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10_p1p2.err

# Phase 1 + Phase 2
setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

echo "=== DIAGNOSTICS ==="
echo "Host: `hostname`"
echo "Date: `date`"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

echo "=== IO package test ==="
/home/user/xyren/software/gap-4.13.1/gap -q -r -b /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/test_io.g
echo "=== IO test exit: $status ==="

echo "=== Starting benchmark: Phase 1 + Phase 2 ==="
cd $HOME/software/gap-4.13.1/pkg/SptSet/examples
/home/user/xyren/software/gap-4.13.1/gap -q -r -b /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/setup_sg10_p1p2.g
echo "=== Benchmark exit: $status ==="
echo "=== End: `date` ==="
