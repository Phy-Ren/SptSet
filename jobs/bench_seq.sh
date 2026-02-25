#!/bin/csh
#PBS -S /bin/csh
#PBS -q normal
#PBS -l nodes=1:ppn=28
#PBS -N sg10_seq
#PBS -o $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10_seq.out
#PBS -e $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10_seq.err

# Sequential (no parallelism)
source ~/miniforge3/etc/profile.d/conda.csh
conda activate gap-centos6

cd /home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples
echo 'SPTSET_PARALLEL_JOBS := 0;; SPTSET_PARALLEL_THRESHOLD := 20;; Read("../debug/bench_sg10_ez.g");;' | /home/user/xyren/software/gap-4.13.1/gap -q -r -b
