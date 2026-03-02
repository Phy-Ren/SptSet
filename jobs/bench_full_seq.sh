#!/bin/csh
#PBS -S /bin/csh
#PBS -q normal
#PBS -l nodes=1:ppn=28
#PBS -N sg10f_seq
#PBS -o $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10f_seq.out
#PBS -e $HOME/software/gap-4.13.1/pkg/SptSet/jobs/sg10f_seq.err

# Sequential (full)
setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

echo "=== DIAGNOSTICS ==="
echo "Host: `hostname`"
echo "Date: `date`"

echo "=== IO test ==="
/home/user/xyren/software/gap-4.13.1/gap -q -r -b /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/test_io.g
echo "=== IO test exit: $status ==="

echo "=== Starting: Sequential (full) ==="
cd $HOME/software/gap-4.13.1/pkg/SptSet/examples
/home/user/xyren/software/gap-4.13.1/gap -q -r -b /home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/setup_sg10f_seq.g
echo "=== Exit: $status ==="
echo "=== End: `date` ==="
