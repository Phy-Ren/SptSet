#!/bin/csh
#PBS -S /bin/csh
#PBS -q extended
#PBS -l nodes=1:ppn=28
#PBS -N sg219fix
#PBS -p 1023
#PBS -o /dev/null
#PBS -e /dev/null

setenv LD_LIBRARY_PATH /home/user/xyren/miniforge3/envs/gap-centos6/lib

set GAP = /home/user/xyren/software/gap-4.13.1/gap
set SETUP = /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/setup/sg219fix.g
set LOG = /home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group/results/sg219fix.log

echo "=== SptSet Space Group #219 (FIX: trivial-page early return) ===" >>& $LOG
echo "Host: `hostname`" >>& $LOG
echo "Date: `date`" >>& $LOG

cd /home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples

echo "Fresh start with fixed ss_vanilla.gi" >>& $LOG
$GAP -q -r -b $SETUP >>& $LOG

echo "=== Exit: $status ===" >>& $LOG
echo "=== End: `date` ===" >>& $LOG
