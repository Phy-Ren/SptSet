# SptSet Checkpoint/Restart 机制

**状态: 全部完成并验证 (2026-02-28)**

## 0. 快速参考

```bash
# 首次运行
CKPT_SG_NUM := 210;; SPTSET_PARALLEL_JOBS := 4;;
Read("jobs/checkpoint_driver.g");;

# 从 checkpoint 恢复
gap -q -r -L ~/checkpoints/sg210.ws -b jobs/checkpoint_driver.g

# PBS 提交（自动检测 resume）
qsub jobs/submit_checkpoint.sh
```

**改动的文件**:

| 文件 | 改动 |
|------|------|
| `read.g` | 新增全局变量 `SPTSET_CHECKPOINT_HOOK`（默认 `false`） |
| `lib/ss_vanilla.gi` | `BuildDerivative` / `BuildDerivative2`: 逐生成元缓存 + checkpoint |
| `lib/ss_module.gi` | `ComponentEx`: 逐 class 缓存; `Result`: 逐层 + 逐 extension 缓存 |
| `jobs/checkpoint_driver.g` | 生产级 driver 脚本（原子写入、详细输出） |

**核心数据结构（新增的 partial 缓存，全部在 ss 对象中）**:

| 缓存 | 位置 | 存储内容 | 完成后自动清理 |
|------|------|---------|---------------|
| `ss!.derivPartial` | ss_vanilla.gi | BuildDerivative 的 partial fA list | 是 |
| `ss!.deriv2Partial` | ss_vanilla.gi | BuildDerivative2 的 partial fA list | 是 |
| `ss!.compExPartial` | ss_module.gi | ComponentEx 的 partial basis_classes | 是 |
| `ss!.resultPartial` | ss_module.gi | Result 的 Exs/nGens/Rmat/doneRow | 是 |

---

## 1. 背景与动机

大型 3D 空间群（SG #210, #219, #228）的 FSPT 分类计算耗时数月。即使有并行加速（Phase 1+2, 约 10x on 28 cores），单次计算也需 1-2 周。这期间：

- PBS 任务有时间限制（normal queue: 60h, extended queue: 180 天）
- 硬件故障、网络中断、电源故障都可能终止任务
- 可能需要暂停和恢复（例如修改并行参数）

没有 checkpoint 意味着任何中断都从零开始，数周计算白费。

## 2. 技术方案

### 2.1 SaveWorkspace 方案（已采用）

GAP 的 `SaveWorkspace("file.ws")` 将整个 GAP 堆（所有对象和全局变量）保存为二进制文件。`gap -L file.ws` 恢复它。

工作原理:

1. 在每个计算步骤完成后，调用 SaveWorkspace 将 ss 对象（含所有缓存）写入磁盘
2. 中断后：`gap -L checkpoint.ws` 恢复完整状态
3. 重新运行 driver 脚本，已缓存的计算自动跳过

为什么可行: SptSet 的谱序列计算有天然的缓存结构。每个 page 计算一次后缓存在 `ss!.modulePages`，微分缓存在 `ss!.derivPages`。SaveWorkspace 保存的就是含这些缓存的完整 ss 对象。

被排除的备选方案:

- **IO_Pickle 手工序列化**: 只序列化缓存数据，重启时重建 resolution + SS + closures。实际不需要，SaveWorkspace 已完美工作，且 closures 经验证可以完整保存/恢复。
- **定时保存**: 每隔固定时间保存一次。不可行，SaveWorkspace 只能在"某个计算结果被缓存到 ss 对象之后"才有意义。如果函数执行到一半（local 变量中的中间结果尚未写入 ss），SaveWorkspace 保存的是不完整状态，恢复后那步还是要从头算。因此必须在每个逻辑计算单元完成后保存，而不是按时间间隔。

### 2.2 细粒度 Checkpoint 设计

核心问题: 最初的 checkpoint 粒度是"每页一个"。但一个 BuildDerivative 可能有数十个生成元，每个算数小时。如果中途被杀，整页的计算全部丢失（可能数天到数周）。

核心约束: Save 的颗粒度上限 = 能被缓存的最小计算单元。要更频繁地 save，必须让更多中间结果缓存到 ss 对象中。

解决方案: 在 ss 对象中新增 partial 缓存结构（见第 0 节表格）。每个最小可缓存单元完成后，将中间结果写入 ss，然后通过全局 hook 触发 SaveWorkspace。

全局 hook 机制:

```gap
# read.g: 库代码通过这个 hook 触发 checkpoint
SPTSET_CHECKPOINT_HOOK := false;  # 默认关闭

# checkpoint_driver.g: 启用 hook，使用原子写入
SPTSET_CHECKPOINT_HOOK := function()
    SaveWorkspace(Concatenation(CKPT_FILE, ".tmp"));
    Exec(Concatenation("mv -f ", CKPT_FILE, ".tmp ", CKPT_FILE));
end;
```

### 2.3 最小可缓存计算单元

每个生成元内部的计算链是原子操作，无法再细分：

```
MapToBarCocycle -> CoboundarySL -> PartialPurify -> MapFromBarCocycle -> project
```

其中 MapFromBarCocycle 最耗时（解大型线性方程组），内部已有 Phase 1 并行。要再细就得修改核心矩阵求解器（bar_resolution_map_common.gi），风险太高，收益有限。

结论: 逐生成元 checkpoint 是实际可行的最细粒度。

### 2.4 所有 Checkpoint 保存点一览

Phase A（分类，约 14 个 page）:

| 步骤 | Save Point | 粒度 |
|------|-----------|------|
| 每个 SptSetSpecSeqComponent | driver 中的 coarse checkpoint | 每页一次 |
| BuildDerivative 中每个生成元 | ss!.derivPartial + hook | 每生成元一次 |
| BuildDerivative2 中每个生成元 | ss!.deriv2Partial + hook | 每生成元一次 |

Phase B（群结构）:

| 步骤 | Save Point | 粒度 |
|------|-----------|------|
| Result Step 1: 每层 ComponentEx | ss!.resultPartial + hook | 每层一次 |
| ComponentEx 中每个 basis class | ss!.compExPartial + hook | 每 class 一次 |
| Result Step 3: 每个 extension 行 | ss!.resultPartial + hook | 每生成元一次 |

SG #10 实测: 总计 97 个 fine-grained checkpoint + 14 个 coarse page checkpoint。

## 3. Checkpoint 与并行的交互

关键结论: Checkpoint 对并行零影响。

| 并行阶段 | Checkpoint 行为 | 影响 |
|---------|----------------|------|
| Phase 1（MapFromBarCocycle 内部） | 完全不介入 | 无 |
| Phase 2（BuildDerivative 生成元间） | ParListByFork 全部完成后 checkpoint 一次 | 无 |
| Phase 2b（Extension 生成元间） | ParListByFork 全部完成后 checkpoint 一次 | 无 |

并行模式下每个 ParListByFork batch 完成后存一次；顺序模式下每个生成元完成后存一次。两者不冲突，由 SPTSET_PHASE2_ENABLED 控制。

### 3.1 跨层并行（不可行）

群结构计算分 4 层，理论上各层独立。但 ParListByFork 要求返回值可被 IO_Pickle 序列化（仅支持 integers, lists, strings, records）。ComponentEx 返回的 SptSetSpecSeqModule 含 GAP closures（basis_classes），无法序列化，因此无法用 fork 跨层并行。

Phase A 的各页计算同理：返回值含 closure 的 FpZModule 对象，且子进程对 ss 缓存的修改不会传回父进程（fork COW 隔离），会导致缓存失效和重复计算。

Step 3（extension）的返回值是整数向量（可序列化），但 Phase 2b 已在层内并行化，跨层额外收益仅约 2%，不值得增加复杂度。

要突破此限制需要 GAP 线程或共享内存支持，当前 GAP 4.x 不提供。

## 4. 存储管理

### 4.1 自动覆盖

每次 SaveWorkspace 都覆盖同一个文件。磁盘上始终只有一个 checkpoint 文件。不需要手动清理，不存在 checkpoint 堆积。

### 4.2 原子写入

先写到 .tmp 文件，再 mv -f 原子替换，防止写入过程中崩溃导致 checkpoint 损坏。最坏情况：丢失当前这次 save，但旧 checkpoint 仍完好。

### 4.3 存储需求

| 空间群 | Workspace 大小 | 瞬时最大占用（含 .tmp） |
|--------|---------------|----------------------|
| SG #10 | 约 134 MB | 约 268 MB |
| SG #210/219 | 约 500 MB - 1 GB | 约 1-2 GB |
| SG #228 | 约 1-2 GB | 约 2-4 GB |

以 16TB NFS 存储来看完全没有压力。Workspace 大小约等于 GAP 进程的堆内存使用量，计算过程中本来就占这么多内存。

## 5. 输出格式

当 SPTSET_CHECKPOINT_HOOK 激活时，所有计算步骤输出详细进度信息。

包含的信息:

| 信息 | 输出位置 | 用途 |
|------|---------|------|
| 生成元数量 m | 每个 derivative/ComponentEx/extension | 预测计算量 |
| 目标维度 target_dim | 每个 derivative | 预测单个生成元计算时间 |
| torsion 阶 | 每层 ComponentEx 和 extension | 了解群结构复杂度 |
| 每步耗时 (ms) | 每个生成元/class/层/parallel batch | 监控进度、预测剩余时间 |
| 总 elapsed 时间 | 每个 Phase A page, Phase B 完成时 | 总体进度 |
| 并行 workers 数 | 每个 parallel batch 完成时 | 确认实际并行度 |
| resume 信息 | ComponentEx/Result 恢复时 | 确认 checkpoint 正确恢复 |

示例输出:

```
[3/14] Computing E^{2,2}_2 (Majorana:)...
  E^{2,2}_2 = Z_2 x Z_2 x Z_2 x Z_4
  Generators: 12, torsion: [2, 2, 2, 4, ...]
  Time: 45230 ms  (elapsed: 127s)

Phase B: Computing group structure...
  Result(deg=4): 4 layers, pRange=[1,2,3,4]
  Step1: layer 1/4 (p=1, q=3)...
    ComponentEx(1,3): 2 generators
    ComponentEx(1,3) class 1/2...
      class 1 done [3421 ms]
  Step1: layer 1 done: 2 generators, torsion=[2,4] [5890 ms]
  Step3: extension computation, 14 tasks across 3 layers [parallel, 4 workers]
    ext layer 1 (p=1): 2 gens done [parallel, 4 workers, 8234 ms]

    d^{2,2}_2: m=12 gens, target_dim=20
    d^{2,2}_2 gen 1/12 (target_dim=20)...
      gen 1 done [12345 ms]
```

## 6. 部署

### 6.1 Driver 脚本

`jobs/checkpoint_driver.g` 是生产级 driver 脚本。

配置变量（在 Read 之前设置）：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| CKPT_SG_NUM | 空间群编号（1-230） | 必需 |
| CKPT_FILE | checkpoint 文件路径 | ~/checkpoints/sgN.ws |
| CKPT_MODE | 模式 "ez" 或 "s12" | "ez" |
| CKPT_DO_EXT | 是否计算群结构 | true |
| SPTSET_PARALLEL_JOBS | 并行 workers 数 | 0 |
| SPTSET_PARALLEL_THRESHOLD | Phase 1 最小维度 | 20 |
| SPTSET_PHASE2_ENABLED | Phase 2 并行开关 | true |

### 6.2 PBS 集成

```csh
#!/bin/csh
#PBS -q extended
#PBS -l nodes=1:ppn=28
#PBS -N sg210_checkpoint

setenv LD_LIBRARY_PATH ~/miniforge3/envs/gap-centos6/lib

if ( -f ~/checkpoints/sg210.ws ) then
    echo "Resuming from checkpoint..."
    ~/software/gap-4.13.1/gap -q -r -L ~/checkpoints/sg210.ws -b ~/jobs/checkpoint_driver.g
else
    echo "Fresh start..."
    ~/software/gap-4.13.1/gap -q -r -b ~/jobs/checkpoint_driver.g
endif
```

任务超时后重新提交即可自动恢复。Extended queue (180 天) 下可长期运行。

## 7. 验证结果

### 7.1 基础验证 (2026-02-26, cluster3)

| 测试 | 结果 | 说明 |
|------|------|------|
| GAP GC 类型 | GASMAN | 支持 SaveWorkspace |
| SaveWorkspace 在 for 循环内 | 通过 | 旧文档说只能在 gap> 提示符下，实际 GAP 4.x 已放宽 |
| Closure 保存/恢复 | 通过 | lambda 捕获的 local 变量、嵌套 closure 全部正确恢复 |
| SptSet SS 对象保存 | 通过 | ss!.modulePages 缓存完整保留 |
| SptSet closure 保存 | 通过 | ss!.bdry, ss!.spectrum, ss!.brMap closures 恢复后正常工作 |
| 恢复后继续计算 | 通过 | 新 page 使用恢复的 closures 正确计算 |
| 恢复速度 | 约 5s | vs 约 30s fresh start |
| Workspace 大小 | 128 MB | C2v 点群 |

### 7.2 Fine-Grained Save/Restore 验证 (2026-02-27/28, SG #10)

Save 测试: 完整计算 SG #10（SPTSET_PARALLEL_JOBS=0）。

- 97 个 fine-grained checkpoint 全部成功
- Workspace 大小: 134 MB
- 最终群结构: [2, 4, 4, 4, 4, 4, 0]

Restore 测试: 从 checkpoint #42 恢复（d2^{2,2}_3 gen 9/12 中间点）。

- 14 个已缓存 modulePages 全部恢复
- deriv2Partial 部分缓存恢复（跳过已算完的生成元 1-8，从 gen 9 继续）
- 继续计算得到群结构 [2, 4, 4, 4, 4, 4, 0]，与完整计算完全一致

### 7.3 关键发现

1. SaveWorkspace 的循环限制已废弃: GAP 4.13.1 中 SaveWorkspace 可在脚本、函数、循环中任意调用。
2. GAP closures 是堆对象: 包括 SptSet 的复杂嵌套 closures（coboundary 公式等），通过 raw memory dump 完整保存/恢复。
3. 双重安全: CKPT_STEP 变量跟踪 driver 进度，ss!.modulePages 缓存独立保证不重复计算。两者互为备份。

## 8. 性能影响

### 8.1 Checkpoint 开销

| 场景 | checkpoint 次数 | 每次耗时 | 总开销 | 占总计算时间 |
|------|----------------|---------|--------|------------|
| SG #10（实测） | 97 次 | 约 1s | 约 2 min | 不到 1% |
| SG #210（估算） | 约 200 次 | 约 5s | 约 17 min | 不到 0.1%（总计约 2 周） |
| SG #228（估算） | 约 500 次 | 约 10s | 约 83 min | 不到 0.05%（总计约 2 月） |

结论: Checkpoint 对计算速度的影响可忽略不计。

### 8.2 对大群的意义

|   | 改动前 | 改动后 |
|---|--------|--------|
| 最大损失 | 整个 BuildDerivative（数天到数周） | 一个生成元的计算（数小时） |
| Phase A checkpoint 总数 | 14（每页一个） | 14 + sum(每个微分的生成元数) |
| Phase B checkpoint 总数 | 1（整体一个） | nLayers + sum(每层生成元数) + sum(extension 数) |

## 9. Q&A 与设计决策

### Q: 为什么不用定时保存？

SaveWorkspace 保存的是 GAP 堆的快照。如果函数执行到一半，中间结果存在 local 变量中（不在堆上的持久对象中），SaveWorkspace 保存不到它们。恢复后函数的 local 状态丢失，那步计算还得从头来。

因此 checkpoint 必须在"某个中间结果被写入 ss 对象"之后才有意义，而不是任意时间点。这就是为什么采用逻辑 checkpoint（每个可缓存单元完成后保存），而非定时 checkpoint。

### Q: 当前的 save 颗粒度是否已经足够细？

是的。整个计算流程中每一个能插入 save point 的地方都已经插入了。计算量最大的 5 个循环（BuildDerivative, BuildDerivative2, ComponentEx, Result Step 1, Result Step 3）全部实现了逐生成元/逐 class/逐层的 fine-grained checkpoint。

剩下无法再细分的是单个生成元内的计算链（MapToBarCocycle -> CoboundarySL -> PartialPurify -> MapFromBarCocycle -> project），这是一个原子操作。要在其中插入 checkpoint 需要修改核心矩阵求解器，风险极高且收益有限（Phase 1 并行已让单个生成元计算足够快）。

### Q: Checkpoint 会不会影响并行计算速度？

不会。Checkpoint hook 不改变任何并行策略。Phase 1（MapFromBarCocycle 内部并行）完全不介入；Phase 2/2b（生成元间并行）在 ParListByFork 全部完成后存一次，不影响并行执行。

如果想要更细的逐生成元 checkpoint（在 Phase 2/2b 区域），可以手动设置 SPTSET_PHASE2_ENABLED := false 来走顺序路径。这是安全性与速度的主动权衡，由用户决定。

### Q: 不同层能不能同时并行算？

不能。根本原因是 GAP 的 fork 并行只能返回 IO_Pickle 可序列化的值（integers, lists, strings, records）。但 ComponentEx 和 SptSetSpecSeqComponent 返回的对象含 GAP closures，无法序列化。此外子进程对 ss 缓存的修改不会传回父进程（fork COW 隔离），会导致缓存失效和重复计算。

要突破此限制需要 GAP 线程或共享内存支持，当前 GAP 4.x 不提供。

### Q: Checkpoint 文件需要手动清理吗？会不会炸存储？

不需要。每次 SaveWorkspace 都覆盖同一文件，磁盘上始终只有一个 checkpoint（加瞬时的 .tmp 文件）。最大的群（SG #228）估计 workspace 约 2GB，瞬时最大约 4GB。16TB NFS 完全没有压力。

## 10. 后续建议

以下是可能的后续改进方向，非必需，视实际使用情况决定：

1. **Workspace 大小监控**: 在大群实际运行时监控 workspace 文件大小，验证估算是否准确。如果超出预期可考虑 GC 优化。

2. **Checkpoint 频率控制**: 当前每个生成元完成后都 save。对于非常小的生成元（几秒完成），可以加一个最小间隔（如 save 间隔大于 60s），减少 I/O。但考虑到当前开销已低于 1%，优先级很低。

3. **多版本 Checkpoint**: 当前只保留最新一个。如果需要回退到更早的状态（例如发现某步计算有 bug），可以改为保留最近 N 个版本。实现简单：在 mv 之前先 cp 旧文件到 .bak。

4. **计算节点验证**: 目前所有测试在 cluster3 login 节点上完成。提交到计算节点（CentOS 6, PBS）前建议做一次快速验证（SG #10，约 5 分钟），确认 NFS 路径、环境变量、GAP 启动参数等无问题。
