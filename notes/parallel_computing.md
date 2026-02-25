# SptSet Parallel Computing: Feasibility Study & Implementation Plan

## 1. Background & Motivation

SptSet is a GAP package for computing Fermionic Symmetry Protected Topological (FSPT) phase classifications via the Atiyah-Hirzebruch Spectral Sequence (AHSS). The computation for 3+1D space groups is extremely slow — a single space group can take **days to months** on a single core. The goal is to accelerate the computation through parallelism, with minimal and safe code changes.

**Current hardware** (see `~/cluster3_note.md` for full details):
- Login node (cluster3): Intel Xeon E5-2603 v4 @ 1.70GHz, 2×6 = 12 cores (no HT), 62GB RAM, Ubuntu 24.04
- Compute nodes (n05-n15, n17): Intel Xeon E5-2680 v4 @ 2.40GHz, 2×14 = 28 cores, ~126GB RAM, **CentOS 6.6**
- Big-memory nodes (n01-n04): same CPU, 28 cores, **~504GB RAM**, CentOS 6.6
- Total: 16 compute nodes, 448 cores. Scheduler: PBS/Torque + Maui (on head node).
- NFS-shared home across all nodes.

**Current GAP version**: GAP 4.13.1, compiled from source on cluster3 with conda gcc 15.2, installed at `~/software/gap-4.13.1/`. Packages: HAP, SptSet, IO, polycyclic, crystcat, etc.

---

## 2. Project Structure

```
SptSet/
├── init.g                          # Loads .gd declaration files
├── read.g                          # Loads .gi implementation files
├── lib/
│   ├── module.g{d,i}               # FpZ-module (generators, projection, relations, SNF)
│   ├── zlmap.g{d,i}                # Z-linear maps, kernel, cokernel, homology
│   ├── coefficient.g{d,i}          # Coefficient systems: U(1), Z_n
│   ├── cochain.g{d,i}              # Cochain modules, coboundary maps
│   ├── inhomo_cocycle.g{d,i}       # Inhomogeneous cocycle operations (cup products, etc.)
│   ├── group_cohomology.g{d,i}     # Group cohomology cochain complexes
│   ├── bar_resolution_map.gd       # Bar resolution map declarations
│   ├── bar_resolution_map_common.gi # ⭐ CORE: ToBarCocycle, FromBarCocycle, SolveCocycleEq
│   ├── bar_resolution_map_mine.gi  # Bar resolution map implementation (ToBarWord, FromBarWord)
│   ├── spectral_sequence.g{d,i}    # Spectral sequence framework (caching of E^{pq}_r pages)
│   ├── ss_vanilla.g{d,i}           # ⭐ CORE: BuildComponent, BuildDerivative (d_r computation)
│   ├── ss_cochain.g{d,i}           # SS cochains, stacking, CoboundarySL
│   ├── ss_class.g{d,i}             # SS classes, PurifySpecSeqClass, PartialPurify
│   ├── ss_fermion.g{d,i}           # Spin-1/2 fermion physical formulas (w, O5, twisters)
│   ├── ss_fermion_ez.g{d,i}        # Spinless fermion physical formulas + LayersVerbose
│   ├── ss_module.g{d,i}            # SpecSeqResult: group structure via layer extension
│   ├── ext_data.g{d,i}             # O5 obstruction lookup tables
│   └── spin12.g{d,i}               # Spin-1/2 factor w_2
├── examples/
│   ├── fspt_3d_simple_ez.g         # 3D classification, spinless, loops 230 space groups
│   ├── fspt_3d_simple_s12.g        # 3D classification, spin-1/2, loops 50 space groups
│   ├── fspt_ez_ext.g               # 3D group structure, spinless, loops 31 point groups
│   ├── fspt_s12_ext.g              # 3D group structure, spin-1/2, loops 31 point groups
│   ├── res_space_group.g           # Resolution3DSpaceGroup helper
│   └── point_group_res.g           # Pre-compute point group resolutions
└── notes/
    └── parallel_computing.md       # This document
```

### Layer hierarchy (top to bottom):
```
ss_fermion.gi / ss_fermion_ez.gi    ← Physical input: differentials, coboundary, twisters
    ↓
ss_vanilla.gi                       ← General AHSS: BuildComponent, BuildDerivative
    ↓
ss_cochain.gi / ss_class.gi         ← Cochain operations, class purification
    ↓
bar_resolution_map_common.gi        ← ⭐ HOT PATH: MapFromBarCocycle, MapToBarCocycle
bar_resolution_map_mine.gi          ← MapToBarWord, MapFromBarWord (with caching)
    ↓
zlmap.gi / module.gi                ← Linear algebra: SmithNormalForm, kernel, homology
```

---

## 3. Computational Pipeline for a Single Group

For a single 3D space group (e.g., space group #i):

```
Step 1: Build resolution
  SG := SpaceGroupBBNWZ(3, i)
  fSG := IsomorphismPcpGroup(SG)
  SG1 := Image(fSG)
  R := Resolution3DSpaceGroup(fSG, 7)
  ─── internally: ResolutionAlmostCrystalGroup(Z^3, 7)
                + ResolutionFiniteGroup(PointGroup, 7)
                + ResolutionExtension(...)

Step 2: Build spectral sequence (fast, just installs closures)
  SS := FermionEZSPTSpecSeq(R, f)
  ─── installs coboundary formulas as closures in ss!.bdry[r][p][q]
  ─── installs stacking twisters as closures in ss!.addTwister[p][q]

Step 3: Compute spectral sequence pages (THE BOTTLENECK)
  FermionSPTLayersVerbose(SS, 3)
  ─── for each (p,q) with p+q ≤ 4, q ∈ {0,1,2,3}:
        for r in [2..rmax]:
          SptSetSpecSeqComponent(ss, r, p, q)   ← triggers derivative chain

Step 4: Compute group structure (ALSO VERY SLOW)
  SptSetSpecSeqResult(ss, 4, [1,2,3,4])
  ─── SptSetSpecSeqComponentEx for each layer
  ─── Layer extension with torsion computation
```

### Step 3 in detail — how E^{pq}_r is built:

```
SptSetSpecSeqComponent(ss, r, p, q)          [spectral_sequence.gi]
  ├── if r=1: return CochainModule(R, p, coeff)    ← fast, just module setup
  └── if r>1: return Homology(d_{r-1} at (p-r+1,q+r-2), d_{r-1} at (p,q))
        ↓
SptSetSpecSeqBuildDerivative(ss, r-1, p, q)  [ss_vanilla.gi, line 110]
  ├── M := E^{pq}_{r-1}, N := E^{p+r-1, q-r+2}_{r-1}
  ├── for i in [1..m] do     ← m = #generators of M (could be 3-50+)
  │     np_ := MapToBarCocycle(brMap, p, coeff, M!.generators[i])
  │     dnp := CoboundarySL(ss, p+q, p, np_)     ← builds physical coboundary layers
  │     cl_dnp := ClassFromCochainNC(dnp)
  │     PartialPurifySSClass@(cl_dnp, ...)        ← ⭐ EXPENSIVE (recursive purification)
  │     opr_ := ... extract obstruction cocycle ...
  │     opr := MapFromBarCocycle(brMap, p+r-1, coeff, opr_)  ← ⭐ VERY EXPENSIVE
  │     fA[i] := opr * N!.projection
  └── return ZLMapByImages(M, N, fA)
```

### The innermost hot loop — `SptSetMapFromBarCocycle`:

```gap
# File: lib/bar_resolution_map_common.gi, lines 47-63
SptSetMapFromBarCocycle := function(brMap, deg, gAction, alpha_)
  n := Dimension(R)(deg);       # n = 100-500+ for 3D space groups at high degree
  val := [];
  for i in [1..n] do            # ← THIS IS THE HOT LOOP
    val[i] := 0;
    fei := SptSetMapToBarWord(brMap, deg, i);   # cached lookup
    for feiw in fei do
      val[i] := val[i] + feiw[1] * (feiw[2]^gAction)[1][1]
        * CallFuncList(alpha_, feiw{[3..(deg+2)]});  # ← evaluates physical formula
    od;
  od;
  return val;
end;
```

**Why this is the bottleneck**:
- `n` is the resolution dimension at degree `deg`. For 3D space groups: n ~ 100-500+.
- `alpha_` is a closure wrapping the physical coboundary formulas (cup products, O5 obstruction, etc.)
- Each `CallFuncList(alpha_, ...)` evaluation involves:
  - For O5 formula: ~20 calls to `n2(g_i, g_j)`, each itself an inhomogeneous cocycle evaluation
  - Each `n2(g_i, g_j)` calls `SptSetMapFromBarWord(brMap, deg, [g_i, g_j])`, which is recursive with caching
- This function is called **dozens to hundreds of times** during a single group's computation:
  - Every `BuildDerivative` call (once per generator per page)
  - Every `PartialPurifySSClass@` (recursive purification)
  - Every `SptSetSolveCocycleEq` (cocycle equation solving)
  - Every `SptSetSpecSeqModuleClassToLeadingVector` (group structure computation)

**Each val[i] is completely independent**: no shared writes, no dependency between iterations.

---

## 4. GAP Parallel Computing Options

### 4.1 IO Package: fork-based parallelism (RECOMMENDED)

The GAP `IO` package provides parallelism via the POSIX `fork()` system call:

```gap
# Low-level:
BackgroundJobByFork(func, args);    # fork + run func(args) in child
WaitUntilIdle(job);                 # wait and get result
Pickup(job);                        # same as above

# High-level skeletons:
ParListByFork(list, worker, rec(NumberJobs := N));  # parallel List()
ParWorkerFarmByFork(func, rec(NumberJobs := N));    # worker pool pattern
```

**How fork() works**: creates an exact copy of the GAP process. The child process has the SAME memory contents (resolution, bar resolution map with caches, all closure functions, spectral sequence object) via copy-on-write. No serialization needed for the GAP state itself — only results (lists of integers) need to be sent back via pipe.

**Key advantage**: ALL closures (alpha_, n2, w, cup products, O5 formula) work correctly in the child because fork copies the entire memory space. This avoids the serialization problem that would make other approaches fail.

**Confirmed working**: HAP's own parallel computation chapter demonstrates 10.4x speedup on 15 cores for embarrassingly parallel group homology computations.

### 4.2 HAP ChildProcess (built on IO fork)

```gap
processes := List([1..N], i -> ChildProcess());
ChildPut(func, "func", process);
ChildCommand("result := func(args);;", process);
result := ChildGet("result", process);
```

Same mechanism as IO fork, with HAP-specific wrappers.

### 4.3 HPC-GAP (shared-memory threads) — NOT RECOMMENDED

- Requires building GAP from source with `--enable-hpcgap`
- Only IO and orb packages confirmed compatible; **HAP compatibility unknown and likely broken**
- Documentation archived since 2017, no longer actively maintained
- Thread safety for GAP's global state (e.g., `R!.elts`, caches) is problematic
- `ward` safety tool removed — cannot detect illegal shared memory access
- **Verdict: too risky, avoid**

### 4.4 SCSCP (distributed, multi-node)

- XML-based protocol for inter-process mathematical communication
- Good for multi-node clusters, but complex setup
- Can be considered for Phase 3 (cluster deployment)

### 4.5 Shell-level orchestration

- Launch multiple independent GAP processes from bash
- Each handles a subset of groups (outer-loop parallelism only)
- Simplest approach, useful for cluster deployment

---

## 5. Implementation Plan

### Phase 1 (PRIMARY): Parallelize `SptSetMapFromBarCocycle`

**Goal**: Accelerate the single-case bottleneck with minimal code changes.

**Target file**: `lib/bar_resolution_map_common.gi`, lines 47-63.

**The change**: Replace the sequential `for i in [1..n]` loop with a parallel version using IO fork.

**Current code**:
```gap
# lib/bar_resolution_map_common.gi, lines 47-63
InstallMethod(SptSetMapFromBarCocycle,
"map from an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsGeneralMapping, IsFunction],
function(brMap, deg, gAction, alpha_)
  local n, val, i, fei, feiw;
  n := Dimension(brMap!.hapResolution)(deg);
  val := [];
  for i in [1..n] do
    val[i] := 0;
    fei := SptSetMapToBarWord(brMap, deg, i);
    for feiw in fei do
      val[i] := val[i] + feiw[1] * (feiw[2]^gAction)[1][1]
        * CallFuncList(alpha_, feiw{[3..(deg+2)]});
    od;
  od;
  return val;
end);
```

**Proposed change** (conceptual):
```gap
InstallMethod(SptSetMapFromBarCocycle,
"map from an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsGeneralMapping, IsFunction],
function(brMap, deg, gAction, alpha_)
  local n, val, i, fei, feiw, nJobs;
  n := Dimension(brMap!.hapResolution)(deg);

  # Pre-populate toBarCache so children don't recompute
  for i in [1..n] do
    SptSetMapToBarWord(brMap, deg, i);
  od;

  # Decide whether to parallelize
  nJobs := SPTSET_PARALLEL_JOBS;  # global config, 0 = disabled
  if nJobs > 0 and n >= SPTSET_PARALLEL_THRESHOLD then
    # Parallel path: each child computes val[i] for its chunk
    val := ParListByFork([1..n], function(idx)
      local v, bar, w;
      v := 0;
      bar := SptSetMapToBarWord(brMap, deg, idx);
      for w in bar do
        v := v + w[1] * (w[2]^gAction)[1][1]
          * CallFuncList(alpha_, w{[3..(deg+2)]});
      od;
      return v;
    end, rec(NumberJobs := Minimum(nJobs, n)));
  else
    # Original sequential path (fallback)
    val := [];
    for i in [1..n] do
      val[i] := 0;
      fei := SptSetMapToBarWord(brMap, deg, i);
      for feiw in fei do
        val[i] := val[i] + feiw[1] * (feiw[2]^gAction)[1][1]
          * CallFuncList(alpha_, feiw{[3..(deg+2)]});
      od;
    od;
  fi;
  return val;
end);
```

**Global configuration variables** (add to `read.g` or a new config file):
```gap
# Number of parallel worker processes. 0 = disabled (sequential fallback).
if not IsBound(SPTSET_PARALLEL_JOBS) then
  SPTSET_PARALLEL_JOBS := 0;
fi;

# Minimum loop size to trigger parallelism. Below this, sequential is faster.
if not IsBound(SPTSET_PARALLEL_THRESHOLD) then
  SPTSET_PARALLEL_THRESHOLD := 20;
fi;
```

**Why this is safe**:
1. Each `val[i]` is fully independent — no shared writes.
2. `fork()` gives each child a complete copy of all state (resolution, caches, closures).
3. Results are plain integers or rationals — trivially serializable via pipe.
4. The original code path is preserved as fallback when `SPTSET_PARALLEL_JOBS = 0`.
5. Only ONE function in ONE file is modified. Everything else is untouched.

**Cache considerations**:
- `toBarCache` (basis → bar word): pre-populated before forking, so children read from cache.
- `fromBarCache` (bar word → basis): used inside `alpha_` closures. After fork, each child gets a copy. New entries computed by children are NOT shared back to parent. This causes some redundant computation but is NOT incorrect.
- In practice, the physical formula evaluation (O5, cup products) dominates the cost, so cache loss is a minor overhead.

**Expected speedup**:
- On cluster3 (12 cores, ~8 workers): **4-6x** per `SptSetMapFromBarCocycle` call.
- On compute node (28 cores, ~20 workers): **8-15x** per call (after resolving CentOS 6 build, see §9.2).
- Since this function is called many times throughout the computation, the aggregate speedup for a full single-case computation is significant. A 3-day computation might become ~12-18 hours on cluster3, or ~5-8 hours on a compute node.

### Phase 2 (SECONDARY): Parallelize `BuildDerivative` generator loop

**Target file**: `lib/ss_vanilla.gi`, lines 130-158.

**The change**: The `for i in [1..m]` loop where each generator's derivative is computed independently. Each `fA[i]` depends only on `M!.generators[i]` and read-only shared state.

```gap
# Current: ss_vanilla.gi lines 130-158
for i in [1..m] do
  np_ := SptSetMapToBarCocycle(ss!.brMap, p, ss!.spectrum[q+1], M!.generators[i]);
  dnp := SptSetSpecSeqCoboundarySL(ss, p+q, p, np_);
  dnp!.layers[p+1 +1] := ZeroCocycle@;
  cl_dnp := SptSetSpecSeqClassFromCochainNC(dnp);
  PartialPurifySSClass@(cl_dnp, r, p+r-1);
  ...
  opr := SptSetMapFromBarCocycle(ss!.brMap, p+r, ss!.spectrum[q-r+1 +1], opr_);
  fA[i] := opr * N!.projection;
od;
```

Each iteration produces `fA[i]` (a row vector of integers) independently. Can be parallelized with `ParListByFork`.

**Benefit**: Each iteration is very expensive (minutes to hours), so even parallelizing 3-5 generators gives good speedup.

**Phase 2 + Phase 1 nesting design** (updated 2025-02-25):

Each Phase 2 child internally calls `SptSetMapFromBarCocycle` multiple times (via PartialPurify, CoboundarySL, etc.). If Phase 1 is also enabled, we get nested fork: Phase 2 forks m workers, each of which triggers Phase 1 forks. This is **supported** as long as total processes <= available cores.

The key mechanism: Phase 2 reduces `SPTSET_PARALLEL_JOBS` before forking, so each child uses fewer Phase 1 workers:

```gap
saved_jobs := SPTSET_PARALLEL_JOBS;
SPTSET_PARALLEL_JOBS := Maximum(0, Int(saved_jobs / m));
fA := ParListByFork([1..m], function(i)
    # child inherits reduced SPTSET_PARALLEL_JOBS via fork()
    # Phase 1 inside uses saved_jobs/m workers per MapFromBarCocycle call
    ...
    return result_row;
end, rec(NumberJobs := Minimum(m, saved_jobs)));
SPTSET_PARALLEL_JOBS := saved_jobs;  # restore in parent
```

Example on 28-core node with `SPTSET_PARALLEL_JOBS := 24`, m=4 generators:
- Phase 2: 4 workers (one per generator)
- Each worker: Phase 1 with `Int(24/4) = 6` sub-workers per MapFromBarCocycle call
- Total concurrent processes: 4 x 6 = 24, fits in 28 cores
- Effective speedup: much better than Phase 1 alone (one call at a time) or Phase 2 alone (4 cores busy, 24 idle)

When `BuildDerivative` is not active, Phase 1 uses all `SPTSET_PARALLEL_JOBS` workers as normal.

**Implementation note**: Both `SptSetSpecSeqBuildDerivative` (lines 110-166) and `SptSetSpecSeqBuildDerivative2` (lines 168-226) have identical `for i in [1..m]` structure. Both must be modified consistently.

**Return value serialization**: Each Phase 2 child returns `fA[i] = opr * N!.projection`, a row vector of integers. This is trivially serializable by `IO_Pickle`.

### Phase 3: Outer-loop parallelism (for batch runs)

**Target**: The `for i in [1..230] do` loop in example scripts.

This is trivially parallelizable since each space group is independent. Two approaches:

**Approach A: GAP-level** (using IO fork):
```gap
results := ParListByFork([1..230], function(i)
    local SG, fSG, SG1, R, gs, f, SS;
    SG := SpaceGroupBBNWZ(3, i);
    # ... full computation for group i ...
    return [i, layers];
end, rec(NumberJobs := 8));
```

**Approach B: Shell-level** (for clusters):
```bash
#!/bin/bash
# run_parallel.sh — launch multiple GAP processes
for START in $(seq 1 30 230); do
    END=$((START + 29))
    [ $END -gt 230 ] && END=230
    gap -r -q run_batch.g -- $START $END > result_${START}.txt 2>&1 &
done
wait
```

Phase 3 is orthogonal to Phases 1-2 and can be combined with them.

---

## 6. Detailed Analysis: Why fork() Works Here

### 6.1 The closure problem

The critical insight is that `alpha_` in `SptSetMapFromBarCocycle` is a GAP closure (lambda function) that captures complex state:

```
alpha_ (the obstruction cocycle)
  └── wraps physical coboundary formulas from ss!.bdry[r][p][q]
        └── these use n2 (another cocycle created by SptSetMapToBarCocycle)
              └── n2 internally calls SptSetMapFromBarWord(brMap, deg, glist)
                    └── uses fromBarCache (a dictionary)
```

GAP closures **cannot be serialized** by `IO_Pickle`. This means approaches that require sending the worker function to a separate process (like SCSCP) would fail.

However, `fork()` does NOT need serialization — the child process inherits the parent's entire address space. The closure, its captured variables, the resolution, the caches — everything is already in memory. This is why fork-based parallelism is uniquely suited to this problem.

### 6.2 What gets parallelized

```
SptSetMapFromBarCocycle(brMap, deg, gAction, alpha_)
  n := Dimension(R)(deg)

  SEQUENTIAL: Pre-populate toBarCache for i in [1..n]

  PARALLEL (fork N workers):
    Worker k handles indices [chunk_start..chunk_end]
    For each i in chunk:
      bar := SptSetMapToBarWord(brMap, deg, i)   ← reads from cache (fast)
      val[i] := Σ_w  w[1] * (w[2]^gAction) * alpha_(w[3..])
                                                  ← evaluates physical formula

  COLLECT: val := concatenation of all worker results
```

### 6.3 Data flow

```
Parent process                     Child process k (after fork)
─────────────────                  ──────────────────────────
brMap (with caches)  ──fork()──→   brMap (copy-on-write, shared read)
alpha_ (closure)     ──fork()──→   alpha_ (identical closure in child)
gAction              ──fork()──→   gAction (copy)

                                   computes val[chunk_start..chunk_end]
                                   ←──pipe──  sends list of integers back

val := assemble results
```

### 6.4 Resolution dimensions (typical values for 3D space groups)

| Degree | Dimension (typical range) | Notes |
|--------|--------------------------|-------|
| 0 | 1 | Trivial |
| 1 | 4-10 | Small |
| 2 | 10-40 | Moderate |
| 3 | 20-100 | Large, d_2 computations here |
| 4 | 40-200 | Very large, d_2 and d_3 here |
| 5 | 80-400 | Huge, d_3 computations here |
| 6 | 150-800 | Massive |

The parallelism (n) is large enough to benefit from 4-8 workers at degrees 3+.

---

## 7. Risk Analysis

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Fork memory overhead | Medium | Medium | Copy-on-write keeps initial overhead low. Monitor with `top`. Reduce NumberJobs if memory pressure. |
| Child cache divergence | Low | Certain | Each child builds its own fromBarCache. Minor redundancy. Physical formula cost dominates. |
| ParListByFork serialization failure | Low | Low | Results are plain integers/rationals. If a result contains a non-serializable object, it will fail. Ensure only basic types are returned. |
| Nested fork (Phase 1 + Phase 2) | Medium | Possible | NEVER nest forks. Use a flag to ensure only one level of parallelism is active. |
| CentOS 6 glibc incompatibility | **High** | **Confirmed** | GAP compiled on Ubuntu 24.04 cannot run on CentOS 6 nodes. Must recompile on compute node using conda gcc. See §9.2. |
| HAP internal bugs amplified | Medium | Medium | Some space groups trigger HAP bugs (e.g., C4v rational assertion). Parallel execution doesn't cause new bugs but may hit existing ones in more groups simultaneously. Add try-catch. |
| Non-deterministic results | Very Low | Very Low | Each fork is a deterministic computation. Results should be identical to sequential. Verify on small cases first. |

---

## 8. Testing Plan

### 8.1 Correctness verification

1. **Pick 3-5 known-good point groups** (e.g., Cs, C2h, S4 — already verified in debug_test_layerwise.g).
2. Run with `SPTSET_PARALLEL_JOBS := 0` (sequential) and record results.
3. Run with `SPTSET_PARALLEL_JOBS := 4` and compare results.
4. Results must be **identical** (not just isomorphic — the actual integer vectors should match).

### 8.2 Performance benchmarking

1. Time individual `SptSetMapFromBarCocycle` calls (add timing around the function).
2. Compare total computation time for one point group with different `SPTSET_PARALLEL_JOBS` values (0, 2, 4, 8).
3. Monitor memory usage with `top` or `htop`.

### 8.3 Stress test

1. Run the full `fspt_ez_ext.g` (31 point groups) with parallelism enabled.
2. Run `fspt_3d_simple_ez.g` on a small subset (e.g., groups 1-10) with parallelism.
3. Check for crashes, hangs, or incorrect results.

---

## 9. Cluster Verification Status (2025-02-25)

### 9.1 What has been verified

| Item | Status | Details |
|------|--------|---------|
| GAP 4.13.1 on cluster3 | ✅ Working | Compiled with conda gcc 15.2, installed at `~/software/gap-4.13.1/` |
| IO package loaded | ✅ Working | `LoadPackage("IO")` returns `true` |
| `ParListByFork` basic test | ✅ Working | `ParListByFork([1..20], i -> i^2, rec(NumberJobs := 4))` returns correct results |
| `ParListByFork` with closures | ✅ Working | Closures capturing external state work correctly in forked children |
| SptSet package loaded | ✅ Working | `LoadPackage("SptSet")` returns `true` (with metadata warnings, harmless) |
| Phase 1 correctness | ✅ Working | Cs s12 point group: both sequential and parallel return `<ZL-Module with torsions [ 16 ]>` |
| Phase 1 speedup | ✅ Measured | See §9.1.1 below |
| GAP on compute nodes | ❌ **FAILED** | See §9.2 below |

### 9.1.1 Phase 1 benchmark results (cluster3, 12 cores @ 1.70GHz)

**Test setup**: SG #10 (P2/m, C2h) resolution, `SptSetMapFromBarCocycle` with synthetic heavy alpha_ closure (matrix computation simulating real O5 workload). Resolution dimensions: deg 4: n=28, deg 5: n=36, deg 6: n=44.

| Workers | deg=4 (n=28) | deg=5 (n=36) | deg=6 (n=44) |
|---------|-------------|-------------|-------------|
| 0 (seq) | 2717 ms | 8856 ms | 27147 ms |
| 4 | 1478 ms (1.84x) | 5545 ms (1.60x) | 17963 ms (1.51x) |
| 8 | 1381 ms (1.97x) | 4939 ms (1.79x) | 15105 ms (1.80x) |

**Correctness**: checksums match perfectly across all configurations (seq: -1800/2600/-5600, par: same).

**Analysis**:
- Speedup on cluster3 (12 cores, 1.70GHz) is **~1.8-2.0x** with 8 workers. Modest because:
  - n is only 28-44 (real space groups have n=100-500+)
  - cluster3 CPU is slow (1.70GHz) with only 12 cores
  - Fork overhead is non-negligible relative to per-item cost at this n
- On compute nodes (28 cores, 2.40GHz) with real space groups (n=100-500+), expect **4-8x** speedup per call
- Point group computations (n=1 everywhere) do NOT benefit from Phase 1
- Script: `debug/benchmark_parallel.g` (Cs s12 correctness), `/tmp/micro_bench2.g` (SG #10 performance)

### 9.2 Compute node incompatibility (BLOCKING for cluster deployment)

The GAP binary compiled on cluster3 (Ubuntu 24.04, glibc 2.39) **cannot run** on compute nodes (CentOS 6.6, glibc 2.12):

```
/home/user/xyren/software/gap-4.13.1/gap: /lib64/libc.so.6: version `GLIBC_2.29' not found
/home/user/xyren/software/gap-4.13.1/gap: /lib64/libc.so.6: version `GLIBC_2.33' not found
/home/user/xyren/software/gap-4.13.1/gap: /lib64/libc.so.6: version `GLIBC_2.34' not found
/home/user/xyren/software/gap-4.13.1/gap: /lib64/libm.so.6: version `GLIBC_2.38' not found
...
```

**Root cause**: cluster3 runs Ubuntu 24.04 (glibc 2.39), compute nodes run CentOS 6.6 (glibc 2.12). The compiled binary requires the newer glibc.

**Good news**: conda's gcc 15.2 **does work** on the compute nodes (verified: `gcc --version` runs on n05). This is because conda-forge builds gcc against a low baseline sysroot. So recompiling GAP on a compute node using conda gcc should work.

**Resolution plan** (deferred, not blocking Phase 1 development):
1. SSH to a compute node via head: `ssh head "ssh n05 bash"`
2. Compile GAP from source there using conda gcc
3. Also rebuild IO, HAP and other C-extension packages
4. The resulting binary (linked against glibc 2.12) should work on both CentOS 6 nodes and Ubuntu 24.04 cluster3
5. Alternatively, maintain two separate builds (one per OS)

**Workaround for now**: Develop and test Phase 1 on cluster3 (12 cores, sufficient for validation). Deploy to compute nodes (28 cores) after resolving the build issue.

### 9.3 Cluster deployment (PBS/Torque)

The cluster uses PBS/Torque + Maui (NOT SLURM). Jobs must be submitted from the head node.

**Single-node PBS script** (for after GAP is compiled for CentOS 6):
```csh
#!/bin/csh
#PBS -S /bin/csh
#PBS -q normal
#PBS -l nodes=1:ppn=28

cd $PBS_O_WORKDIR
# Activate conda for gcc runtime libraries
source ~/miniforge3/etc/profile.d/conda.csh
conda activate base
~/software/gap-4.13.1-centos6/gap -r -q run_parallel.g
```

**Multi-node** (outer-loop parallelism via separate PBS jobs):
```bash
# Submit one job per space group range
for START in $(seq 1 30 230); do
    END=$((START + 29))
    [ $END -gt 230 ] && END=230
    ssh head "cd ~/software/gap-4.13.1/pkg/SptSet && qsub -v START=$START,END=$END submit_batch.sh"
done
```

Each node uses `SPTSET_PARALLEL_JOBS := 20` for inner parallelism (28 cores, leave some for OS overhead).

### 9.4 Multi-node single-case acceleration (analysis, 2025-02-25)

**Question**: Can multiple compute nodes (16 nodes x 28 cores = 448 cores) accelerate a single space group computation?

**Short answer**: Very difficult. `fork()` only works within a single machine. Cross-node parallelism requires sending data over the network, but the critical `alpha_` closure **cannot be serialized**.

**Why closures block multi-node**:
```
Node A (computing)                     Node B (wants to help)
──────────────────                     ────────────────────
alpha_ closure ✓                       alpha_ ??? ← cannot be sent
  └── captures n2 cocycle                  GAP closures are not
  └── captures intermediate results        serializable by IO_Pickle
  └── captures cached bar words            or any GAP mechanism
```

`fork()` avoids serialization by copying the entire process memory. But you cannot `fork()` onto a different physical machine.

**Possible workaround: `SaveWorkspace`**

GAP's `SaveWorkspace("file.ws")` dumps the entire heap (including closures) to a binary file. `gap -L file.ws` restores it. Theoretically:
1. Node A computes to an expensive BuildDerivative entry point
2. `SaveWorkspace("/home/user/shared/state.ws")` (NFS-shared)
3. Nodes B, C, D: `gap -L state.ws` → full state restored including closures
4. Each node computes different generators, writes results to NFS files
5. Node A collects results and continues

**Issues with SaveWorkspace approach**:
- Workspace file could be hundreds of MB; loading takes time
- Must save/restore at each expensive computation point (many times per case)
- Uncertain whether all HAP/SptSet objects survive save/restore correctly
- Significant engineering effort to restructure the computation flow
- Requires custom coordination logic (which node does what, result collection)

**Verdict**: Multi-node single-case is theoretically possible but requires major engineering effort with uncertain reliability. Not recommended as next step.

**Recommended priority**:
1. Phase 2+1 on single node (28 cores) — practical, implementable now, 5-15x expected
2. Phase 3 across nodes (different cases on different nodes) — trivial, combinable with above
3. Multi-node single-case via SaveWorkspace — future research if 28-core speedup is insufficient

### 9.5 Scale-up: renting high-core-count servers (analysis, 2025-02-25)

Since fork-based parallelism is limited to a single node, the bottleneck is the core count per node. Current cluster nodes have 28 cores (Xeon E5-2680 v4, 2016 era). Modern servers offer much more:

| Configuration | Cores/Threads | Freq | RAM | Price | vs our 28-core node |
|---------------|---------------|------|-----|-------|---------------------|
| Our cluster n05 | 28c/28t | 2.40 GHz | 126 GB | free | 1x baseline |
| EPYC 9654 (1P) | 96c/192t | 2.4/3.7 GHz | 768 GB | ~$1,200/mo | ~6-8x |
| EPYC 9655P (1P) | 96c/192t | 2.6/4.5 GHz | 768 GB | ~$1,500/mo | ~8-10x |
| **EPYC 9965 (2P)** | **384c/768t** | 2.25/3.7 GHz | **2.3 TB** | **~$1,600/mo** | **~20-30x** |

Best option: **AMD EPYC 9965 dual-socket** bare metal (e.g., ReliableSite, ~$1,600/mo).
- 384 cores with Phase 2+1 nesting: m=10 generators x 38 sub-workers = 380 concurrent processes
- 2.3 TB RAM: no memory pressure from fork (CoW overhead ~50-100 GB for 384 processes)
- IPC improvement (Zen 5 vs Broadwell): ~2-3x per core
- Combined speedup: 20-40x per single case vs current cluster node

**Memory analysis for fork**:
- GAP process with resolution + caches: ~200-500 MB
- 384 fork processes (copy-on-write): ~50-100 GB actual (shared pages dominate)
- 2.3 TB available: completely safe, no risk of OOM
- 126 GB on current cluster: marginal for large space groups with many forks

**Cost-effectiveness**:
- A computation taking 30 days on 1 cluster node → ~1-2 days on EPYC 9965
- $1,600/mo rental for 1-2 months = $1,600-3,200 total
- Alternative: use current cluster's 16 nodes for outer-loop parallelism (free, but only helps for batch runs, not single-case speedup)

---

## 10. Summary of Recommended Actions

| Priority | Action | Target File | Change Size | Expected Speedup | Status |
|----------|--------|-------------|-------------|------------------|--------|
| **P0** | Add global config variables | `read.g` | ~5 lines | N/A (infrastructure) | ✅ Done |
| **P1** | Parallelize `SptSetMapFromBarCocycle` | `bar_resolution_map_common.gi` | ~30 lines | ~2x on cluster3, 4-8x expected on nodes | ✅ Done |
| **P1.5** | Compile GAP for CentOS 6 compute nodes | build scripts | ~1 hour work | unlocks 28-core nodes | DONE |
| **P2** | Parallelize `BuildDerivative` generator loop | `ss_vanilla.gi` | ~30 lines | 2-4x per derivative | DONE |
| **P3** | Outer-loop parallelism in example scripts | `examples/*.g` | ~20 lines each | ~Nx for N cores | TODO |
| **P4** | Cluster deployment scripts (PBS) | new shell scripts | ~50 lines | multi-node scaling | TODO |

**Status**: P0-P2 done. P1.5 done (conda env `gap-centos6` with `sysroot_linux-64=2.12`). Benchmark jobs submitted: SG #10 ez on n05 (seq), n06 (P1), n07 (P1+P2).

---

## Appendix A: Key Function Signatures and Locations

### `SptSetMapFromBarCocycle` (PRIMARY TARGET)
- **File**: `lib/bar_resolution_map_common.gi`, lines 47-63
- **Signature**: `(brMap, deg, gAction, alpha_) → list of integers`
- **Called by**: `SptSetSpecSeqBuildDerivative`, `SptSetSpecSeqBuildDerivative2`, `PartialPurifySSClass@`, `PartialPurifyCoboundary@`, `SptSetSpecSeqModuleClassToLeadingVector`, `SptSetSpecSeqModuleClassToVector`, `SolveU1CocycleEq@`, `SptSetSolveCocycleEq`
- **Inner loop**: `for i in [1..n]` where n = resolution dimension at degree deg

### `SptSetSpecSeqBuildDerivative` (SECONDARY TARGET)
- **File**: `lib/ss_vanilla.gi`, lines 110-166
- **Signature**: `(ss, r, p, q) → ZLMap`
- **Inner loop**: `for i in [1..m]` where m = number of generators of E^{pq}_r
- **Note**: `SptSetSpecSeqBuildDerivative2` (lines 168-226) has identical structure

### `SptSetMapToBarWord` (cache pre-warming)
- **File**: `lib/bar_resolution_map_mine.gi`, lines 107-130
- **Signature**: `(brMap, deg, i) → list of bar words`
- **Caching**: `brMap!.toBarCache[deg+1][i]`

### `SptSetMapFromBarWord` (used inside alpha_ closures)
- **File**: `lib/bar_resolution_map_mine.gi`, lines 132-165
- **Signature**: `(brMap, deg, glist) → list of HAP words`
- **Caching**: `brMap!.fromBarCache[deg+1]` (dictionary keyed by glist)

### `FermionSPTLayersVerbose` / `FermionEZSPTLayersVerbose`
- **File**: `lib/ss_fermion_ez.gi`, lines 368-436
- **Loops over**: (p, q) positions, computes E^{pq}_r for r=2..rmax

### `SptSetSpecSeqResult` (group structure)
- **File**: `lib/ss_module.gi`, lines 258-340
- **Step 1**: Compute ComponentEx for each layer (potentially parallelizable)
- **Step 3**: Layer extension (sequential, depends on previous layers)

---

## Appendix B: IO Package Quick Reference

```gap
LoadPackage("IO");

# ParListByFork — parallel version of List()
result := ParListByFork(
    [1..100],                    # input list
    function(i) return i^2; end, # worker function
    rec(NumberJobs := 4)         # options
);
# result = [1, 4, 9, 16, ..., 10000]

# BackgroundJobByFork — manual control
job := BackgroundJobByFork(function(args) return args[1]^2; end, [42]);
result := Pickup(job);  # blocks until done, returns 1764
Kill(job);              # cleanup (if not using TerminateImmediately)

# ParWorkerFarmByFork — worker pool
farm := ParWorkerFarmByFork(
    function(i) return i^2; end,
    rec(NumberJobs := 4)
);
for i in [1..100] do Submit(farm, [i]); od;
while not IsIdle(farm) do DoQueues(farm, true); od;
results := Pickup(farm);
Kill(farm);
```

**Important**: `ParListByFork` handles all forking, communication, and result collection internally. The worker function runs in a forked child process that has the FULL parent state. Results must be serializable by `IO_Pickle` (integers, rationals, lists, strings, records — NOT arbitrary GAP objects).
