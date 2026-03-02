#!/bin/csh
#PBS -S /bin/csh
#PBS -q extended
#PBS -l nodes=1:ppn=28
#PBS -N sg001
#PBS -o /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/results/sg001.out
#PBS -e /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/results/sg001.err

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

set GAP = /home/user/xyren/software/gap-4.13.1/gap
set SETUP = /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/setup/sg001.g
set CKPT = ~/checkpoints/sg1.ws

echo "=== SptSet Space Group #1 ==="
echo "Host: `hostname`"
echo "Date: `date`"

cd /home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples

if ( -f $CKPT ) then
    echo "Resuming from checkpoint..."
    $GAP -q -r -L $CKPT -b $SETUP
else
    echo "Fresh start."
    $GAP -q -r -b $SETUP
endif

echo "=== Exit: $status ==="
echo "=== End: `date` ==="
