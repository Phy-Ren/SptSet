# SptSet Checkpoint/Restart Mechanism

## 1. Background & Motivation

The FSPT classification for large 3D space groups (SG #210, #219, #228) takes **months** of computation on a single core. Even with parallel acceleration (Phase 1+2, ~10x on 28 cores), a single computation may take **1-2 weeks**. During this time:

- PBS jobs have wall-time limits (normal queue: 60h, extended queue: 180 days)
- Hardware failures, network issues, or power outages can kill the job
- We may want to pause and resume (e.g., to change parallel settings mid-computation)

Without checkpointing, any interruption means starting over from scratch — **weeks of computation lost**.

**Status: FULLY VERIFIED (2026-02-26)** — see §8 for test results.

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

**Verification status** (2026-02-26): **ALL VERIFIED ✅**
- `SaveWorkspace` / restore of basic GAP objects: ✅ Verified on cluster3
- `SaveWorkspace` from inside for loops: ✅ Works (old "only at gap> prompt" restriction relaxed)
- `SaveWorkspace` of SptSet spectral sequence with caches: ✅ Verified — cached pages survive restore
- Compatibility with closures in `ss!.bdry`: ✅ Verified — all closures (coboundary formulas, spectrum, brMap) survive save/restore
- Compatibility with IO/fork: ✅ Works (no active pipes at checkpoint time)
- Resumed computation correctness: ✅ Verified — new pages computed correctly after restore
- Restore speed: ✅ ~5s (vs ~30s fresh start with LoadPackage)
- GAP 4.13.1 GC: GASMAN (SaveWorkspace supported)
- Workspace file size: 128MB for small point group; estimate 500MB-2GB for large space groups

**Pros**:
- Zero library code changes — only a driver script
- Saves EVERYTHING (resolution, caches, closures, all intermediate state)
- Restoration is instant (load binary file)

**Cons**:
- Workspace file may be large (128MB for small group; estimate 500MB-2GB for large space groups)
- Cannot save mid-function-call (only between top-level statements)

**Driver script**: See `jobs/checkpoint_driver.g` for the production-ready implementation.
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
| ~~Page computation takes days (can't checkpoint mid-page)~~ | ~~High~~ **RESOLVED** | ~~Accept: checkpoint granularity = per page.~~ **§9 实现了逐生成元 checkpoint，最坏丢失一个生成元（数小时），而非整页（数天）。** |

~~The last risk is important: we cannot checkpoint mid-page.~~ **已解决 (2026-02-27)**: §9 的细粒度 checkpoint 在 BuildDerivative/BuildDerivative2/ComponentEx/SpecSeqResult 中逐生成元保存，checkpoint 粒度从"每页"细化到"每个生成元"。详见 §9。

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

See `jobs/checkpoint_driver.g` and `jobs/submit_checkpoint.sh` for production-ready scripts.

## 8. Verification Results (2026-02-26)

All tests performed on cluster3 (GAP 4.13.1, GASMAN GC).

| Test | Result | Details |
|------|--------|---------|
| GAP GC type | GASMAN | `GAPInfo.KernelInfo.GC` returns `"GASMAN"` |
| SaveWorkspace inside for loop | **PASS** | Saves successfully, no error |
| Closure survival (basic) | **PASS** | Lambda capturing local variables survives save/restore |
| SptSet SS object save | **PASS** | `ss!.modulePages` cache preserved after restore |
| SptSet closure survival | **PASS** | `ss!.bdry`, `ss!.spectrum`, `ss!.brMap` closures work after restore |
| Continued computation after restore | **PASS** | New pages computed correctly using restored closures |
| Checkpoint-resume cycle | **PASS** | Steps 1-4 saved, restored at step 4, steps 5-7 computed correctly |
| Restore speed | ~5s | vs ~30s fresh start with `LoadPackage` |
| Workspace file size (C2v point group) | 128 MB | Estimate for SG #210/228: 500MB-2GB |

**Conclusion**: SaveWorkspace (Approach A) is fully viable. No need for Approach B (manual cache serialization) or Approach C (hybrid). All previously identified risks have been resolved.

### Key discoveries:
1. The old GAP doc restriction "SaveWorkspace can only be used at the main gap> prompt" was relaxed in GAP 4.x. It now works inside loops and in scripts.
2. GAP closures (including complex nested closures like those in SptSet's coboundary formulas) are GAP heap objects and survive SaveWorkspace/restore via raw memory dump.
3. Restore is much faster than fresh start because packages are already loaded in the workspace.
4. Dual safety: CKPT_STEP variable tracks checkpointed progress, AND SptSet's internal caching (`ss!.modulePages`) independently skips re-computation.

## 9. Fine-Grained Checkpoint (2026-02-27)

### 9.1 问题

§5 第 5 条风险指出：**无法在单页计算中途 checkpoint**。如果一个 BuildDerivative 有 m 个生成元，每个算几小时，中途被杀就全丢。对大群（SG #210/219/228），这可能意味着丢失数天到数周的计算。

**核心约束**: SaveWorkspace 只能在"某个计算结果被缓存到 ss 对象之后"才有意义。如果中间结果没有被缓存，SaveWorkspace 保存的就是一个不完整的状态，重启后还是要从头算那一步。

**结论**: 要想 save 得更频繁，必须让更多的中间结果缓存到 ss 对象里。Save 的颗粒度上限 = 能被缓存的最小计算单元。

### 9.2 计算流程的完整缓存分析

**已有缓存（自动生效，改动前就存在）：**

| 缓存位置 | 存储内容 | 生命周期 |
|----------|---------|---------|
| `ss!.modulePages[r+1][p+1][q+1]` | E^{p,q}_r 模块 | 计算一次后永久缓存 |
| `ss!.module2Pages[r+1][p+1][q+1]` | tilde{E}^{p,q}_r 模块 | 同上 |
| `ss!.derivPages[r+1][p+1][q+1]` | d^{p,q}_r 微分映射 | 同上 |
| `ss!.deriv2Pages[r+1][p+1][q+1]` | tilde{d}^{p,q}_r 微分映射 | 同上 |

这 4 个缓存表保证了已算完的 Component 和 Derivative 不会被重复计算。改动前的 driver 在每个 SptSetSpecSeqComponent 调用后 SaveWorkspace，保护了这些缓存。

**改动前未缓存的（丢失风险最高的部分）：**

1. **`BuildDerivative` 中 m 个生成元的 for 循环** — 每个 fA[i] 可能算数小时，但全存在 local 变量里，SaveWorkspace 保存不到。
2. **`BuildDerivative2` 同样的循环** — 完全相同的问题。
3. **`SptSetSpecSeqComponentEx` 中逐生成元的 class 构建** — 每个生成元要做 PurifySpecSeqClass（涉及多次 MapFromBarCocycle），结果只在 local list 中。
4. **`SptSetSpecSeqResult` Step 1 的 ComponentEx 结果** — 4 个层的 ComponentEx 结果不缓存。
5. **`SptSetSpecSeqResult` Step 3 的逐生成元扩展系数** — Rmat 的 off-diagonal 块逐行计算，不缓存。

### 9.3 改动方案与实现

**设计原则**: 在 ss 对象中新增 partial 缓存结构，在每个最小可缓存单元完成后将中间结果写入 ss 对象，然后调用全局 checkpoint hook。重启后，这些缓存的中间结果被自动检测到并跳过。

**全局 hook 机制** (`read.g`):
```gap
if not IsBound(SPTSET_CHECKPOINT_HOOK) then
    SPTSET_CHECKPOINT_HOOK := false;  # 默认关闭，不影响原有行为
fi;
```

Driver 脚本设置 hook:
```gap
SPTSET_CHECKPOINT_HOOK := function()
    SaveWorkspace(CKPT_FILE);
end;
```

**改动的 4 个位置：**

#### (1) `BuildDerivative` (`lib/ss_vanilla.gi`)
新增 `ss!.derivPartial[r+1][p+1][q+1]` 缓存 partial fA list。
```gap
# 重启后检测已缓存的 partial 结果
if IsBound(ss!.derivPartial[r+1][p+1][q+1]) then
    fA := ss!.derivPartial[r+1][p+1][q+1];  # 已算完的生成元
fi;
for i in [1..m] do
    if not IsBound(fA[i]) then  # 跳过已缓存的
        # ... 计算 fA[i] ...
        ss!.derivPartial[r+1][p+1][q+1] := fA;
        SPTSET_CHECKPOINT_HOOK();  # 每个生成元存一次
    fi;
od;
Unbind(ss!.derivPartial[...]);  # 全部完成后清理
```

**关键设计**: 当 `SPTSET_CHECKPOINT_HOOK <> false` 时，自动强制走顺序路径（禁用 Phase 2 并行），这样每个生成元算完都能立即 checkpoint。每个生成元独享全部 Phase 1 worker，性能不会显著下降。

#### (2) `BuildDerivative2` (`lib/ss_vanilla.gi`)
完全同构的改动，使用 `ss!.deriv2Partial` 缓存。

#### (3) `SptSetSpecSeqComponentEx` (`lib/ss_module.gi`)
新增 `ss!.compExPartial[p+1][q+1]` 缓存 partial basis_classes。
每构建一个 class（涉及 SptSetSpecSeqClassFromLevelCocycle → PurifySpecSeqClass），checkpoint 一次。

#### (4) `SptSetSpecSeqResult` (`lib/ss_module.gi`)
新增 `ss!.resultPartial[deg+1]` 缓存：
- `Exs[pi]` — 每层 ComponentEx 完成后缓存 + checkpoint
- `Rmat` + `doneRow` — 每个 off-diagonal 生成元完成后缓存 + checkpoint

当 checkpoint hook 激活时，Step 3 也强制走顺序路径。

### 9.4 改进效果：Save Point 数量对比

以 dim=3 FSPT 计算为例（14 个页面 + 群结构）：

| 阶段 | 改动前 Save Point | 改动后 Save Point |
|------|-------------------|-------------------|
| Phase A: 分类（14 页） | 14（每页一个） | 14 + Σ(每个微分的生成元数) |
| Phase B: 群结构 | 1（整体一个） | nLayers + Σ(每层生成元数) + Σ(off-diagonal 生成元数) |

**SG #10 实测** (2026-02-27, cluster3):

Classification 阶段触发的细粒度 checkpoint 统计：
- `d2^{1,3}_2`: 2 generators → 2 checkpoints
- `d2^{2,2}_2`: 12 generators → 12 checkpoints
- `d2^{1,3}_3`: 1 generator → 1 checkpoint
- `d2^{3,1}_2`: 20 generators → 20 checkpoints
- `d2^{2,2}_3`: 12 generators → 12+ checkpoints
- ... (更多微分)

仅分类阶段就从 **14 个 save point** 增加到 **60+ 个**（加上群结构部分更多）。

**对大群 SG #210/219/228 的意义**:
这些群的微分生成元数远多于 SG #10（可能达到 50-100+），且每个生成元可能算数小时。改动前中断 = 丢失整个 BuildDerivative（可能数天到数周）。改动后中断 = 最多丢失一个生成元的计算量（数小时）。

### 9.5 不可再细的最小计算单元

每个生成元内部的计算链是 **原子操作**，无法在中间断开缓存：

```
MapToBarCocycle → CoboundarySL → PartialPurify → MapFromBarCocycle → project
```

其中 `MapFromBarCocycle` 是最耗时的步骤（解大型线性方程组）。它内部已有 Phase 1 并行（fork 多个 worker 并行求解矩阵列），但是单次线性代数运算没有自然的缓存中间点。

要想再细，需要修改核心矩阵求解器（`bar_resolution_map_common.gi` 中的 `MapFromBarCocycle`），在矩阵按列求解的过程中逐列缓存。这改动极深（动核心线性代数层），风险太高，收益有限（Phase 1 并行已经让单列计算很快），不建议做。

**结论**: 当前实现的 **逐生成元 checkpoint** 是实际可行的最细粒度。

### 9.6 对计算效率的影响

**SaveWorkspace 本身的开销**:
- SG #10 workspace 文件约 128 MB
- SaveWorkspace 执行时间：约 0.5-2 秒（写入 NFS）
- 大群 workspace 预计 500MB-2GB，写入时间 2-10 秒

**频率与总开销估算**:

| 场景 | 估计 checkpoint 次数 | 每次耗时 | 总开销 | 占总计算时间比例 |
|------|---------------------|---------|--------|---------------|
| SG #10（小群） | ~60 次 | ~1s | ~1 min | < 1%（总计 ~30min） |
| SG #210（大群） | ~200 次 | ~5s | ~17 min | < 0.1%（总计 ~2 周） |
| SG #228（最大群） | ~500 次 | ~10s | ~83 min | < 0.05%（总计 ~2 月） |

**Phase 2 并行的取舍**:

当 checkpoint hook 激活时，BuildDerivative 中的 Phase 2 并行（生成元级并行）被禁用，改为顺序执行。但每个生成元获得全部 Phase 1 worker，所以：

- Phase 2 并行：m 个生成元同时跑，每个分配 `JOBS/m` 个 Phase 1 worker
- Checkpoint 顺序：1 个生成元跑，分配全部 `JOBS` 个 Phase 1 worker

对于大 m、计算量均匀的情况，Phase 2 理论更快（线性加速）。但实际上 fork 开销和内存竞争使 Phase 2 加速比远小于 m。顺序模式下每个生成元得到更多 Phase 1 worker，且没有 fork 开销，实际性能差距通常在 2x 以内。

**总结: SaveWorkspace 的开销可以忽略不计（< 0.1%），Phase 2 取舍是唯一实质影响，但换来的是从"可能丢数周"到"最多丢数小时"的安全性提升，完全值得。**
