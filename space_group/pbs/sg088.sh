#!/bin/csh
#PBS -S /bin/csh
#PBS -q long
#PBS -l nodes=1:ppn=28
#PBS -N sg088
#PBS -o /dev/null
#PBS -e /dev/null

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

set GAP = /home/user/xyren/software/gap-4.13.1/gap
set SETUP = /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/setup/sg088.g
set CKPT = ~/checkpoints/sg88.ws
set LOG = /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/results/sg088.log

echo "=== SptSet Space Group #88 ===" >>& $LOG
echo "Host: `hostname`" >>& $LOG
echo "Date: `date`" >>& $LOG

cd /home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples

if ( -f $CKPT ) then
    echo "Resuming from checkpoint..." >>& $LOG
    $GAP -q -r -L $CKPT -b $SETUP >>& $LOG
else
    echo "Fresh start." >>& $LOG
    $GAP -q -r -b $SETUP >>& $LOG
endif

echo "=== Exit: $status ===" >>& $LOG
echo "=== End: `date` ===" >>& $LOG
