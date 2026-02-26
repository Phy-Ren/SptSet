# SptSet Checkpoint/Restart Mechanism

## 1. Background & Motivation

The FSPT classification for large 3D space groups (SG #210, #219, #228) takes **months** of computation on a single core. Even with parallel acceleration (Phase 1+2, ~10x on 28 cores), a single computation may take **1-2 weeks**. During this time:

- PBS jobs have wall-time limits (normal queue: 60h, extended queue: 180 days)
- Hardware failures, network issues, or power outages can kill the job
- We may want to pause and resume (e.g., to change parallel settings mid-computation)

Without checkpointing, any interruption means starting over from scratch — **weeks of computation lost**.

## 2. Why Checkpointing is Feasible for SptSet

SptSet's spectral sequence computation has a **natural caching structure** that makes checkpointing almost free:

```gap
# lib/spectral_sequence.gi, SptSetSpecSeqComponent:
if not IsBound(ss!.modulePages[r+1][p+1][q+1]) then
    ss!.modulePages[r+1][p+1][q+1] := SptSetSpecSeqBuildComponent(ss, r, p, q);
fi;
return ss!.modulePages[r+1][p+1][q+1];
```

Each page E^{pq}_r is computed once and cached in `ss!.modulePages`. If we save the `ss` object to disk and restore it later, re-running the computation **automatically skips all cached pages** — only uncached pages are computed.

Similarly, derivatives are cached in `ss!.derivPages`, and Component2/Derivative2 in `ss!.module2Pages`/`ss!.deriv2Pages`.

## 3. The Computation Flow (for reference)

For 3D FSPT with `FermionSPTLayersVerbose(ss, 3)`:

```
p=1, q=3 (p+ip layer):
  r=2: E^{1,3}_2 → calls BuildDerivative at (1,3) and neighbors
  r=3: E^{1,3}_3 → calls BuildDerivative at (1,3) page 2
  r=4: E^{1,3}_4

p=2, q=2 (Majorana layer):     ← MOST EXPENSIVE for large groups
  r=2: E^{2,2}_2 → BuildDerivative(ss, 1, 2, 2) → large generator count
  r=3: E^{2,2}_3

p=3, q=1 (Complex fermion layer):
  r=2: E^{3,1}_2
  r=3: E^{3,1}_3
  r=4: E^{3,1}_4

p=4, q=0 (Bosonic layer):
  r=2: E^{4,0}_2
  r=3: E^{4,0}_3
  r=4: E^{4,0}_4
  r=5: E^{4,0}_5
```

Each page is computed sequentially (each depends on previous pages). But once computed, it's cached. The total number of pages is small (~12-15), but each page can take hours to days for large groups.

## 4. Checkpoint Approaches

### 4.1 Approach A: SaveWorkspace (simplest)

GAP's `SaveWorkspace("file.ws")` saves the entire GAP heap (all objects, all global variables) to a binary file. `gap -L file.ws` restores it.

**How it works**:
1. After each expensive page is computed, call `SaveWorkspace("checkpoint.ws")`
2. The `ss` object (with all cached pages) is saved
3. If interrupted: `gap -L checkpoint.ws` restores full state
4. Re-run the computation script — cached pages are skipped automatically

**Verification status** (2025-02-26):
- `SaveWorkspace` / restore of basic GAP objects: ✅ Verified on cluster3
- `SaveWorkspace` of SptSet spectral sequence with caches: 🔍 Testing in progress
- Compatibility with closures in `ss!.bdry`: ⚠️ Risk — closures reference function objects that must survive save/restore
- Compatibility with IO/fork: ✅ Should work (no active pipes at checkpoint time)

**Pros**:
- Zero library code changes — only a driver script
- Saves EVERYTHING (resolution, caches, closures, all intermediate state)
- Restoration is instant (load binary file)

**Cons**:
- Workspace file may be large (100MB - several GB for large groups)
- `SaveWorkspace` is deprecated in GAP 4.12+ (still works in 4.13.1)
- Closures may not survive save/restore if internal function references break
- Cannot save mid-function-call (only between top-level statements)

**Driver script pattern**:
```gap
# checkpoint_driver.g
# Usage:
#   First run:  gap -q -r -b checkpoint_driver.g
#   Resume:     gap -q -r -L checkpoint.ws -b checkpoint_driver.g

if not IsBound(ss) then
    # First run: build everything from scratch
    LoadPackage("HAP");; LoadPackage("IO");; LoadPackage("SptSet");;
    # ... build resolution, create SS ...
    Print("Fresh start.\n");;
else
    Print("Resumed from checkpoint. Cached pages will be skipped.\n");;
fi;

# Compute pages with checkpoint after each
for p in [1..(dim+1)] do
    q := dim + 1 - p;
    if q < 0 or q > 3 then continue; fi;
    rmax := Maximum(q+2, p+1);;
    for r in [2..rmax] do
        t := NanosecondsSinceEpoch();;
        Erpq := SptSetSpecSeqComponent(ss, r, p, q);;
        dt := Int((NanosecondsSinceEpoch() - t) / 1000000);;
        SptSetFpZModuleCanonicalForm(Erpq);;
        Print("E^{", p, ",", q, "}_", r, " = "); Display(Erpq);;
        Print("  Time: ", dt, " ms\n");;
        if dt > 10000 then
            SaveWorkspace("checkpoint.ws");;
            Print("  Checkpoint saved.\n");;
        fi;
    od;
od;
```

### 4.2 Approach B: Manual cache serialization (robust)

Instead of saving the entire workspace, serialize only the cache data using `IO_Pickle`.

**How it works**:
1. After each page, pickle `ss!.modulePages` (contains integer matrices) to a file
2. On restart: rebuild resolution + SS from scratch (rebuilds closures), then inject cached pages

**Pros**:
- No closure serialization issues — only integer matrices are pickled
- Smaller checkpoint files (just the cache, not the whole heap)
- Works even if SaveWorkspace is broken for closures
- Forward-compatible (no dependency on GAP workspace format)

**Cons**:
- Must rebuild resolution + SS on restart (~5-30 minutes for large groups)
- Need to also save `ss!.derivPages`, `ss!.module2Pages`, `ss!.deriv2Pages`
- FpZModule objects inside the cache may not be directly picklable by IO_Pickle
  (custom pickling might be needed — extract integer matrices, pickle those)
- More code changes needed

**Pattern**:
```gap
# Save cache
SaveSptSetCache := function(ss, filename)
    local stream, pages;
    stream := OutputTextFile(filename, false);
    # Extract raw integer data from cached pages
    # ... (implementation depends on FpZModule structure)
    IO_Pickle(stream, pages);
    CloseStream(stream);
end;

# Restore cache
RestoreSptSetCache := function(ss, filename)
    local stream, pages;
    stream := InputTextFile(filename);
    pages := IO_Unpickle(stream);
    CloseStream(stream);
    # Inject back into ss
    ss!.modulePages := pages;
end;
```

### 4.3 Approach C: Hybrid (recommended)

Use SaveWorkspace as primary checkpoint, with manual cache export as fallback.

1. Try SaveWorkspace first (zero effort)
2. If restore fails (closure issues), fall back to manual cache injection
3. Keep the manual export code ready but only use it if needed

## 5. Key Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Closures don't survive SaveWorkspace | Medium | Fall back to Approach B (rebuild SS + inject cache) |
| Workspace file too large | Low | Large groups have large resolutions, but disk is 16TB NFS |
| SaveWorkspace deprecated | Low | Still works in GAP 4.13.1; migrate to IO_Pickle if removed |
| Checkpoint during fork | Low | Only checkpoint after ParListByFork returns (no active children) |
| Page computation takes days (can't checkpoint mid-page) | High | Single page = single BuildDerivative call. Phase 2 parallelizes generators but can't checkpoint mid-BuildDerivative. Accept: checkpoint granularity = per page. |

The last risk is important: **we cannot checkpoint mid-page**. If a single page takes 3 days to compute and the job is killed after 2 days, those 2 days are lost. The previous pages are safe (cached), but the in-progress page must be recomputed from scratch.

For the hardest groups (SG #228 with O_h), a single page (e.g., E^{2,2}_2 at the Majorana layer) might take days. If this is interrupted, only that one page is lost — all other completed pages survive.

## 6. Implementation Plan

1. **Test SaveWorkspace with SptSet** (priority: immediate)
   - Compute a few pages of SG #10, save workspace, restore, verify cache works
   - Check workspace file size

2. **Write checkpoint driver script** (priority: before submitting SG #210/219/228 jobs)
   - Replace `FermionSPTLayersVerbose` with explicit loop + SaveWorkspace
   - Add timing output per page
   - Add checkpoint interval (only save if page took > N seconds)

3. **Prepare manual cache export as fallback** (priority: if SaveWorkspace fails)
   - Write SaveSptSetCache / RestoreSptSetCache functions
   - Test with a known group

## 7. PBS Integration

For cluster deployment, the checkpoint mechanism integrates with PBS as follows:

```csh
#!/bin/csh
#PBS -S /bin/csh
#PBS -q extended          # 180-day limit
#PBS -l nodes=1:ppn=28
#PBS -N sg210_checkpoint

setenv LD_LIBRARY_PATH ~/miniforge3/envs/gap-centos6/lib

# Check if checkpoint exists
if ( -f ~/checkpoints/sg210.ws ) then
    echo "Resuming from checkpoint..."
    ~/software/gap-4.13.1/gap -q -r -L ~/checkpoints/sg210.ws -b ~/jobs/checkpoint_driver.g
else
    echo "Fresh start..."
    ~/software/gap-4.13.1/gap -q -r -b ~/jobs/checkpoint_driver.g
endif
```

If the job times out (60h in normal queue), resubmit and it resumes from the last checkpoint. With the extended queue (180 days, xyren has access), a single job can run for months with periodic checkpoints.
