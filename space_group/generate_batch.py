#!/usr/bin/env python3
"""Generate setup .g and PBS .sh files for a batch of space groups.

Usage:
    python3 generate_batch.py                    # default batch
    python3 generate_batch.py 21 40              # SG#21-40, extended queue
    python3 generate_batch.py 21 40 bigmem       # SG#21-40, bigmem queue
"""

import os
import sys
import stat

BASE = "/home/user/xyren/software/gap-4.13.1/pkg/SptSet/space_group"
DRIVER = "/home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/checkpoint_driver.g"
EXAMPLES = "/home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples"
GAP_BIN = "/home/user/xyren/software/gap-4.13.1/gap"
LD_PATH = "/home/user/xyren/miniforge3/envs/gap-centos6/lib"

HARDEST = {210, 219, 228}

def gen_setup(n, jobs=24, threshold=10):
    if n in HARDEST:
        jobs, threshold = 26, 5
    lines = [
        'CKPT_SG_NUM := %d;;' % n,
        'CKPT_MODE := "ez";;',
        'CKPT_DO_EXT := true;;',
        'SPTSET_PARALLEL_JOBS := %d;;' % jobs,
        'SPTSET_PARALLEL_THRESHOLD := %d;;' % threshold,
        'SPTSET_PHASE2_ENABLED := true;;',
        'Read("%s");;' % DRIVER,
    ]
    return '\n'.join(lines) + '\n'

def gen_pbs(n, queue="extended"):
    p = "%03d" % n
    if n in HARDEST:
        queue = "extended"
        tag = " (HARDEST)"
    elif queue == "bigmem":
        tag = " (bigmem node)"
    else:
        tag = ""

    log_file = "%s/results/sg%s.log" % (BASE, p)

    lines = [
        '#!/bin/csh',
        '#PBS -S /bin/csh',
        '#PBS -q %s' % queue,
        '#PBS -l nodes=1:ppn=28',
        '#PBS -N sg%s' % p,
        '#PBS -o /dev/null',
        '#PBS -e /dev/null',
        '',
        'setenv LD_LIBRARY_PATH %s' % LD_PATH,
        '',
        'set GAP = %s' % GAP_BIN,
        'set SETUP = %s/setup/sg%s.g' % (BASE, p),
        'set CKPT = ~/checkpoints/sg%d.ws' % n,
        'set LOG = %s' % log_file,
        '',
        'echo "=== SptSet Space Group #%d%s ===" >>& $LOG' % (n, tag),
        'echo "Host: `hostname`" >>& $LOG',
        'echo "Date: `date`" >>& $LOG',
        '',
        'cd %s' % EXAMPLES,
        '',
        'if ( -f $CKPT ) then',
        '    echo "Resuming from checkpoint..." >>& $LOG',
        '    $GAP -q -r -L $CKPT -b $SETUP >>& $LOG',
        'else',
        '    echo "Fresh start." >>& $LOG',
        '    $GAP -q -r -b $SETUP >>& $LOG',
        'endif',
        '',
        'echo "=== Exit: $status ===" >>& $LOG',
        'echo "=== End: `date` ===" >>& $LOG',
    ]
    return '\n'.join(lines) + '\n'

def generate(sg_list, queue="extended"):
    os.makedirs(os.path.join(BASE, "setup"), exist_ok=True)
    os.makedirs(os.path.join(BASE, "pbs"), exist_ok=True)
    os.makedirs(os.path.join(BASE, "results"), exist_ok=True)

    for n in sg_list:
        p = "%03d" % n
        setup_path = os.path.join(BASE, "setup", "sg%s.g" % p)
        with open(setup_path, "w") as f:
            f.write(gen_setup(n))

        pbs_path = os.path.join(BASE, "pbs", "sg%s.sh" % p)
        with open(pbs_path, "w") as f:
            f.write(gen_pbs(n, queue))
        st = os.stat(pbs_path)
        os.chmod(pbs_path, st.st_mode | stat.S_IXUSR | stat.S_IXGRP)

    print("Generated %d setup + PBS script pairs:" % len(sg_list))
    for n in sg_list:
        p = "%03d" % n
        q = "extended" if n in HARDEST else queue
        print("  sg%s  [%s]" % (p, q))

if __name__ == "__main__":
    if len(sys.argv) >= 3:
        start = int(sys.argv[1])
        end = int(sys.argv[2])
        q = sys.argv[3] if len(sys.argv) >= 4 else "extended"
        generate(list(range(start, end + 1)), queue=q)
    else:
        batch1 = list(range(1, 21)) + [210, 219, 228]
        generate(batch1)
