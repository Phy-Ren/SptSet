#!/bin/csh
#PBS -S /bin/csh
#PBS -q normal
#PBS -l nodes=1:ppn=28
#PBS -N sg10_p1p2
#PBS -o $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10_p1p2.out
#PBS -e $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10_p1p2.err

# Phase 1 + Phase 2 (both levels parallel)
source ~/miniforge3/etc/profile.d/conda.csh
conda activate gap-centos6

cd /home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples
echo 'SPTSET_PARALLEL_JOBS := 24;; SPTSET_PARALLEL_THRESHOLD := 10;; SPTSET_PHASE2_ENABLED := true;; Read("../debug/bench_sg10_ez.g");;' | /home/user/xyren/software/gap-4.13.1/gap -q -r -b
