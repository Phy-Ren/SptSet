# 230 空间群系统计算计划

**状态: 运行中 (2026-03-17 更新) | 已完成 84/230 | ModRat bug 2个 | Assertion 警告 9个 | fix 任务运行中 (Step 7)**

> ⚠️ **2026-03-17 重大修正**: §12.5 中关于 fix 效果的分析存在严重错误。
> d2^{2,2}\_3 并**没有被消除**——它从 Step 4 推迟到了 Step 7，仍需完整计算。
> Fix 任务的实际剩余时间为 **10-25 天**，而非之前估算的 1-3 天。
> 原始 sg210/sg219/sg228 任务已于 3/17 误取消，损失了 ~300h+ 的计算进度。
> **fix 任务绝对不可再取消。**

## 1. 背景

SptSet 包用于计算 3+1D Fermionic SPT 相分类（Atiyah-Hirzebruch 谱序列方法）。目标是系统性地计算全部 230 个三维空间群的 FSPT 分类和群结构（ez 模式 / spinless fermion）。

已完成的基础设施：

| 模块 | 状态 | 说明 |
|------|------|------|
| Phase 1 并行 (MapFromBarCocycle) | ✅ 完成 | 内层循环 fork 并行 |
| Phase 2 并行 (BuildDerivative) | ✅ 完成 | 生成元间 fork 并行 |
| Phase 2b 并行 (Extension) | ✅ 完成 | extension j-loop 并行 |
| Fine-grained checkpoint | ✅ 完成 | 逐生成元/逐 class/逐层保存 |
| Checkpoint driver | ✅ 完成 | `jobs/checkpoint_driver.g` |
| PBS 自动恢复 | ✅ 完成 | `jobs/submit_checkpoint.sh` |
| CentOS 6 编译 | ✅ 完成 | conda gcc, gap-centos6 环境 |

SG #10 (C2h, point group order 4) 基准测试结果（28 cores @ 2.40GHz, n05）：

| 配置 | 分类 | 群结构 | 总计 | 加速比 |
|------|------|--------|------|--------|
| 顺序 (JOBS=0) | 2.7h | 2.7h | 5.4h | 1.00x |
| P1+P2 (JOBS=24) | 1.0h | 1.9h | 3.0h | 1.82x |

结果：Z_2 × Z_4^5 × Z（已验证正确）

---

## 2. 目标

1. **完成全部 230 个 3D 空间群的 ez 模式计算**
   - Phase A: FSPT 分类（谱序列各页 E^{p,q}_r）
   - Phase B: 最终群结构（层扩展 + SNF）

2. **每个空间群产出完整结果记录**，包括：
   - 分类层（Bosonic, Complex fermion, Majorana, p+ip 各层的 E_∞ 页）
   - 最终群结构（Smith normal form）
   - Resolution 维度
   - 各阶段计算时间（Phase A, Phase B, 总时间）
   - 并行统计（P1/P2/P2b 调用次数和时间）
   - 错误信息（如有）

3. **充分利用集群资源**，保持计算节点满载运行

---

## 3. 服务器资源

### 3.1 集群配置

| 节点 | 数量 | CPU | 核心 | 内存 | 系统 |
|------|------|-----|------|------|------|
| n01-n04 (bigmem) | 4 | Xeon E5-2680 v4 @ 2.40GHz | 28 | 504GB | CentOS 6.6 |
| n05-n15, n17 (normal) | 12 | Xeon E5-2680 v4 @ 2.40GHz | 28 | 126GB | CentOS 6.6 |
| cluster3 (login) | 1 | Xeon E5-2603 v4 @ 1.70GHz | 12 | 62GB | Ubuntu 24.04 |
| **合计** | **16** | — | **448** | — | — |

### 3.2 PBS 队列

| 队列 | 最大时间 | 适用节点 | 备注 |
|------|---------|----------|------|
| debug | 30 min | 所有 | 快速测试 |
| normal | 60h (2.5d) | n05-n17 | 常规任务 |
| bigmem | 60h (2.5d) | n01-n04 | 大内存任务 |
| long | 336h (14d) | 所有 | 长时间任务 |
| extended | 4320h (180d) | **仅 normal 节点** | 超长任务 (xyren 有权限) |

> **关键发现 (2026-02-28)**: Maui 调度器为 extended 队列的 job 隐式添加
> `Features: [normal]`，导致 extended 队列 **无法使用 bigmem 节点**。
> 即使 PBS 的 `qmgr` 配置中 extended 队列没有显式限制节点类型，
> Maui 的默认行为仍阻止 extended job 运行在 bigmem 属性的节点上。
>
> **影响**: 最难的 3 个空间群 (210/219/228) 只能在 extended 队列的 **normal 节点**
> （126GB RAM）上运行。bigmem 节点用来跑普通空间群（bigmem 队列，60h 限制，
> checkpoint 保护）。
>
> **Maui fair-share 注意**: Maui 根据用户的历史+当前资源使用率计算 StartPriority。
> 排队 INFINITY walltime 的 extended 任务过多会导致优先级变负（-15000+），
> 使新任务被 BLOCKED。解决方法是控制排队任务数量，先清队列让紧急任务启动，
> 再逐步补充排队任务。

### 3.3 存储

- NFS 共享 home: 16TB (已用 8.8TB, 剩余约 7TB)
- Checkpoint 文件: 最大 ~2GB/个 (SG #228), 230 个总计保守估计 <50GB
- 结果文件: 每个 <1MB, 可忽略

### 3.4 当前节点使用情况 (2026-03-05 20:00)

**集群 100% 满载 (16/16 节点)**。xyren 占 5 节点，其他用户占 11 节点。

| 节点 | 占用者 | Job ID | 备注 |
|------|--------|--------|------|
| n01 (bigmem) | **chlau** | 114168 | ~2.5d 剩余 |
| n02 (bigmem) | xyren | 114159 (SG#64) | Phase A step 4 |
| n03 (bigmem) | **cchen** | 114132 | ~12.8d 剩余，用 206GB RAM |
| n04 (bigmem) | **chlau** | 114166 | ~2.5d 剩余 |
| n05 (normal) | xyren | 114092 (**SG#219**) | Phase A step 4 |
| n06,n10-n14 (normal) | **ybli** | 113979 (6节点) | ~22h 剩余 |
| n07 (normal) | **cchen** | 113969 | ~8d 剩余 |
| n08 (normal) | **cchen** | 113970 | ~8d 剩余 |
| n09 (normal) | xyren | 114141 (SG#61) | Phase A step 4 |
| n15 (normal) | xyren | 114049 (**SG#228**) | Phase A step 4 |
| n17 (normal) | xyren | 114091 (**SG#210**) | Phase A step 4 |

排队中：SG#067 (extended), SG#065 (bigmem), SG#066 (bigmem)。

> **Fair-share 状况**: xyren 使用率 40.87% (目标 10%) → StartPriority = -15320。
> 当节点释放时 xyren 的 job 会被调度器降优先级。
> ybli 的 6 节点任务约 22h 后到期，届时 6 个 normal 节点将释放。
>
> **已修复**: monitor.sh 新增 `cancel_stale_jobs()` 函数自动取消已完成 SG 的僵尸排队作业。
> SG#017 僵尸作业已手动取消。monitor cron 已自动补充 SG#067。

---

## 4. 难度分级与时间估算

### 4.1 难度因素

计算复杂度主要取决于：
1. **点群阶数 |G_pt|**: 决定 resolution 维度，高阶 → 维度更大
2. **Resolution 维度 n**: MapFromBarCocycle 的循环大小，n=100-600
3. **生成元数量 m**: BuildDerivative 的循环大小
4. **微分阶数**: d_2, d_3 层可能有不同复杂度

SG #10 (|G_pt|=4) 参考数据：
- Resolution 维度: deg3=20, deg5=36, deg7=52
- 28 核总耗时: 3.0h (P1+P2)

SG #210/219 (|G_pt|=24) 估计：
- Resolution 维度: deg3~120, deg5~220, deg7~310
- Resolution 构建本身就需 18+ 分钟

SG #228 (|G_pt|=48) 估计：
- Resolution 维度: deg3~240, deg5~440, deg7~620
- 计算量是 SG #10 的数百到数千倍

### 4.2 分级估算

230 个空间群对应 32 个晶体点群。粗略按点群阶数分级：

| 等级 | 点群阶数 | 估计 SG 数量 | 单个 28 核预估时间 | 代表群 |
|------|---------|-------------|-------------------|--------|
| Tier 0 (trivial) | 1 | 1 | 秒 | SG #1 (P1) |
| Tier 1 (easy) | 2 | ~15 | 分钟 | SG #2 (P-1) |
| Tier 2 (moderate) | 4 | ~30 | ~3h | SG #10 (P2/m) |
| Tier 3 (hard) | 6-8 | ~50 | ~1d | |
| Tier 4 (very hard) | 12-16 | ~50 | ~3-7d | |
| Tier 5 (extreme) | 24 | ~30 | ~2-4w | SG #210, #219 |
| Tier 6 (最难) | 48 | ~10 | ~1-4mo | SG #228 |

**重要**: 以上时间是非常粗略的估算，实际时间可能差异很大。前几批完成后将有更准确的数据。

### 4.3 三个最难空间群

| SG # | 名称 | 点群 | |G_pt| | 预估时间 | 实际队列 |
|------|------|------|--------|---------|---------|
| 210 | F4₁32 | O (432) | 24 | 数周-数月 | extended (normal 节点) |
| 219 | F-43c | T_d (-43m) | 24 | 数周-数月 | extended (normal 节点) |
| 228 | Fd-3c | O_h (m-3m) | 48 | 数月 | extended (normal 节点) |

这三个的配置：
- **Extended 队列 + normal 节点**（126GB RAM；因 extended 无法使用 bigmem 节点）
- **最大并行配置**: `JOBS=26, THRESHOLD=5, PHASE2=true`
- **INFINITY walltime**: 不会被时间限制中断
- 如果 126GB 内存不足（OOM），降低 JOBS 数后重新提交

---

## 5. 计划架构

### 5.1 核心原则

- **每个空间群 = 一个独立 PBS job = 一个计算节点**
- **所有 job 使用同一个 checkpoint_driver.g**（参数化）
- **PBS 调度器自动分配节点**，提交后无需人工干预
- **Checkpoint 保护**：任何中断自动恢复，不丢失进度
- **实时 .log 输出**：可随时查看任务进度和错误（见第 8 节）

### 5.2 文件结构

见第 10 节。每个 SG 有独立的 `setup/sgNNN.g` 和 `pbs/sgNNN.sh`，方便调试。

### 5.3 参数配置

所有普通空间群统一配置：

| 参数 | 值 | 说明 |
|------|-----|------|
| CKPT_MODE | "ez" | Spinless fermion |
| CKPT_DO_EXT | true | 计算群结构 |
| SPTSET_PARALLEL_JOBS | 24 | 并行 worker 数（28核留4核余量） |
| SPTSET_PARALLEL_THRESHOLD | 10 | Phase 1 并行最小维度 |
| SPTSET_PHASE2_ENABLED | true | Phase 2 并行开关 |

三个最难空间群 (210/219/228) 的专用配置：

| 参数 | 值 | 说明 |
|------|-----|------|
| PBS 队列 | extended | INFINITY walltime |
| PBS 节点 | normal | 126GB RAM（extended 无法使用 bigmem） |
| SPTSET_PARALLEL_JOBS | 26 | 更激进的并行（28核留2核余量） |
| SPTSET_PARALLEL_THRESHOLD | 5 | 更低的并行阈值，小任务也并行 |

---

## 6. 提交策略

### 6.1 队列策略 (2026-03-17 修订: extended+long)

| 队列 | 用途 | walltime | 节点类型 | MAXPROC 限制 |
|------|------|---------|---------|-------------|
| **extended** | **仅 3 个 fix 任务** | 4320h (180天) | 所有节点 | **168 (6节点上限)** |
| **long** | **所有其他 SG** | 336h (14天) | 所有节点 | 无限制 |

**不再使用 bigmem 和 normal 队列。** 理由:
- extended 有 Maui HARD MAXPROC=168 限制（最多 6 个节点）
- 原始 sg210/sg219/sg228 已取消 (3/17), 仅保留 3 个 fix 任务 (sg210fix/sg219fix/sg228fix)
- long 队列可访问**所有 16 个节点**（包括 n01-n04 bigmem 节点），14 天足够绝大多数 SG
- 不需要 bigmem 的额外内存，long 的 14 天 >> bigmem 的 2.5 天
- long 队列无 MAXPROC 限制，可以填满所有空闲节点

### 6.2 脚本生成

使用 `generate_batch.py` 批量生成：

```bash
cd space_group/

# 生成 SG#21-50 到 long 队列（默认）
python3 generate_batch.py 21 50

# 210/219/228 无论指定什么队列，自动强制 extended
python3 generate_batch.py 210 210
```

210/219/228 无论指定什么队列，脚本会自动强制使用 extended 队列和 JOBS=26/THRESHOLD=5。

### 6.3 自动管理 (monitor.sh)

**不再需要手动提交**。monitor.sh 自动完成所有工作：

```bash
# 安装 cron（每 5 分钟执行一次）
cd space_group/
./monitor.sh --cron

# 手动执行一次
./monitor.sh

# 查看状态
./monitor.sh --status

# 预览不执行
./monitor.sh --dry-run
```

monitor.sh 的核心逻辑（详见附录 C）：
1. **HARDEST 保护**：sg210/219/228 (含 fix 变体) 始终用 extended，绝不取消
2. **滴灌式补充 long**：保持 3 个 long idle 任务，完成一个补一个
3. 多余的 long idle 自动取消（防止 fair-share 压力）
4. 检测中断的任务（有 checkpoint 但不在 PBS）并重新提交到 long
5. 清理已完成 SG 的 checkpoint（**绝不删除 210/219/228 的 checkpoint**）

### 6.4 三个最难空间群 — 绝对保护规则 ⚠️⚠️⚠️

SG #210fix/219fix/228fix 使用 extended 队列 + normal 节点，INFINITY walltime。

> ⚠️ **血泪教训 (2026-03-17)**: 原始 sg210/sg219/sg228 任务在 Step 4 已运行 345h+，
> 因错误分析认为 fix 消除了瓶颈而被取消，损失了 **~300h+** 的计算进度。
> d2^{2,2}\_3 并没有被消除，只是从 Step 4 推迟到了 Step 7，fix 任务仍需从头计算。
> **这种错误绝不能重复。**

**以下规则任何情况下都不可违反：**

| 规则 | 说明 |
|------|------|
| ❌ **禁止取消** | **无论任何理由**都不得 qdel sg210fix/sg219fix/sg228fix |
| ❌ **禁止基于时间预估取消** | 预估可能严重失准，**绝不基于预估做取消决策** |
| ❌ 禁止删除 checkpoint | **即使计算完成也不删除** checkpoint 文件 |
| ❌ 禁止修改脚本 | 运行中不得修改 setup/pbs 文件 |
| ❌ 禁止重新提交 | 除非确认任务已不在 PBS 中（crash/节点故障） |
| ✅ 最高优先级 | monitor.sh 通过控制其他任务的排队数量保证优先级 |
| ✅ 持续监控 | 定期检查 .log 和 checkpoint 时间戳确认存活 |
| ✅ **长时间无输出是正常的** | Step 7 可能连续运行数周无日志输出，**不代表卡死** |

monitor.sh 中这三个 SG 被标记为 HARDEST，自动执行以下保护：
- 不参与 cleanup（不会被取消）
- checkpoint 不参与自动清理
- 如果不在 PBS 中（crash），自动重新提交到 extended

---

## 7. 结果记录格式

### 7.1 每个空间群的输出

checkpoint_driver.g 已内置详细输出，包括：

```
============================================================
SptSet Checkpoint Driver
  Space group: #10
  Mode: ez
  Checkpoint file: ~/checkpoints/sg10.ws
  Parallel: JOBS=24 THRESHOLD=10 PHASE2=true
  Group structure: true
============================================================
Building resolution for SG #10...
  Resolution built in 1234 ms
  Dimensions: 1 4 10 20 34 52 74

Phase A: Classification (14 pages)
------------------------------------------------------------
[1/14] Computing E^{1,3}_2 (p+ip:)...
  E^{1,3}_2 = <ZL-Module with torsions [ 2, 0 ]>
  Generators: 2, torsion: [2, 0]
  Time: 123 ms  (elapsed: 2s)
  Checkpoint saved (step 1/14).
...

Phase B: Computing group structure...
  Result(deg=4): 4 layers, pRange=[1,2,3,4]
  ...

============================================================
ALL DONE: SG #10 (ez)
============================================================
Total elapsed: 10800 s

Classification layers:
  Bosonic:          E^{4,0}_inf = ...
  Complex fermion:  E^{3,1}_inf = ...
  Majorana:         E^{2,2}_inf = ...
  p+ip:             E^{1,3}_inf = ...

Group structure: <ZL-Module with torsions [ 2, 4, 4, 4, 4, 4, 0 ]>

=== SptSet Parallel Stats ===
Config: JOBS=24 THRESHOLD=10 PHASE2=true
P1 (MapFromBarCocycle): 19 parallel calls ...
P2 (BuildDerivative): 8 calls ...
P2b (SpecSeqResult ext): 1 calls ...
```

### 7.2 汇总表格式 (summary.csv)

`collect_results.sh` 脚本解析所有 .out 文件，生成 CSV：

```csv
sg_num,status,classification_bosonic,classification_cf,classification_majorana,classification_pip,group_structure,time_phase_a_s,time_phase_b_s,time_total_s,res_dim_6,error
1,done,"Z","Z","Z_2","Z_2 x Z","Z_2 x Z^2",12,8,20,4,
2,done,"Z_2^6","Z_2^5","Z_2^5","Z_2 x Z","Z_2 x Z_4^5 x Z",3600,6900,10500,74,
...
210,running,,,,,,,,,,
228,running,,,,,,,,,,
```

### 7.3 错误分类

已知可能遇到的错误：

| 错误类型 | 原因 | 影响 | 处理方式 |
|---------|------|------|---------|
| Assertion: rational in cochain | 微分/共边界公式问题 (如 C3v, C4v) | Phase A 可能中止 | 记录错误，跳过该 SG，后续修复 |
| **ModRat coprime error** | `SptSetFpZModuleCanonicalElm` 中 `vp[i] mod R[i][i]` 对 ModRat 元素不兼容 | **Phase A 正常完成，Phase B Step3 extension 崩溃** | 分类结果有效；群结构需修复 module.gi:191 |
| Memory exhaustion (OOM) | fork 后内存不足 | 进程被 kill | 降低 JOBS 数或用 bigmem 节点 |
| PBS walltime exceeded | 计算时间超限 | job 被终止 | Checkpoint 自动恢复，重新提交 |
| GAP internal error | HAP 或 SptSet bug | 不可预测 | 记录详细错误信息 |
| NFS I/O error | 网络/存储问题 | checkpoint 损坏风险 | 原子写入已保护；重新提交 |

---

## 8. 监控与实时输出

### 8.1 实时输出机制

PBS 默认缓冲 stdout/stderr，仅在 job 结束时写入 `-o`/`-e` 指定的文件。
为解决此问题，PBS 脚本内部将所有输出重定向到 `.log` 文件（实时写入）：

```csh
set LOG = .../results/sgNNN.log
echo "..." >& $LOG        # 第一行覆盖写
$GAP ... >>& $LOG          # 追加写（stdout + stderr 一起）
```

PBS 的 `-o`/`-e` 设为 `/dev/null`，不再使用。

> **注意**: 早期提交的任务（SG#11-14, SG#210, SG#219）使用旧脚本，没有 .log。
> 这些任务只能通过 checkpoint 文件和进程检查来监控（见 8.3）。
> 后续重启/新提交的任务都使用新脚本，有实时 .log。

### 8.2 查看实时进度

```bash
# 查看某个 SG 的实时输出
tail -f space_group/results/sg026.log

# 查看最新进度（末尾 30 行）
tail -30 space_group/results/sg026.log

# 查看所有已完成的 SG
grep -l "ALL DONE" space_group/results/*.log

# 查看哪些 SG 出错了
grep -l "Error" space_group/results/*.log
```

### 8.3 手动监控方法

```bash
# 1. 查看全部任务状态
ssh head 'showq -u xyren'

# 2. 查看 checkpoint 文件（时间戳 = 最后一次保存）
ls -la ~/checkpoints/sg*.ws

# 3. 检查某个节点上的 GAP 进程是否存活
ssh head 'ssh n15 "ps aux | grep gap | grep -v grep"'

# 4. 查看 Maui fair-share 状态
ssh head 'diagnose -f -v | grep xyren'

# 5. 查看 job 详情（优先级、节点、Features）
ssh head 'checkjob <JOB_ID>'
```

### 8.4 自动监控脚本 (monitor.sh)

`monitor.sh` 每 5 分钟自动执行一次（cron），实现以下功能：

1. **自动补充任务**：维持 bigmem 队列 2 个 idle + normal 队列 2 个 idle
2. **自动取消有害任务**：检测并取消非 hardest SG 的 INFINITY 排队（防止 fair-share 崩溃）
3. **自动重启中断任务**：发现有 checkpoint 但不在 PBS 中的 SG → 自动重新提交
4. **自动清理 checkpoint**：已完成的 SG 自动删除 checkpoint 释放磁盘
5. **按需生成脚本**：提交前自动调用 `generate_batch.py` 生成/更新 PBS 脚本

```bash
# 手动执行一次监控周期
./monitor.sh

# 查看当前状态
./monitor.sh --status

# 预览（不实际操作）
./monitor.sh --dry-run

# 安装 cron（每 5 分钟自动执行）
./monitor.sh --cron
```

**队列策略**（不使用 normal 队列）：
- 新任务首次 → `bigmem`（60h）或 `extended`（INFINITY）
- hardest SG (210/219/228) → `extended` 队列（INFINITY）
- **重提交策略**: bigmem 60h 到期 → checkpoint 保护进度，monitor 重提交到 **extended**（不再放回 bigmem）。
  理由：有过一次 resume 说明耗时已超 60h，继续放 bigmem 会再次到期
- **错误检测**: monitor.sh 检测 ModRat/Resolution 模式错误，以及通用崩溃（GAP 异常退出但未完成）。
  通过日志中 `=== Exit:` 标记区分 bug 崩溃和 walltime 中断：有 Exit 但没 ALL DONE → 崩溃，不重提交；没有 Exit → walltime 中断，安全重提交

监控日志：`space_group/monitor.log`

---

## 9. 确认的决策 (2026-02-28)

### 9.1 队列分配策略 ✅ (已更正)

| 任务类型 | 队列 | 节点类型 | walltime | 说明 |
|---------|------|---------|---------|------|
| SG #210/219/228 | extended | normal | INFINITY | **绝对保护，不可触碰** |
| 普通 SG (normal 节点) | extended | normal | INFINITY | monitor.sh 滴灌式补充 |
| 普通 SG (bigmem 节点) | bigmem | bigmem | 60h | 不浪费 bigmem 节点，到期 checkpoint 恢复 |

> **不使用 normal 队列**。所有 normal 节点任务统一用 extended (INFINITY walltime)。
> Maui fair-share 问题通过 monitor.sh 控制排队数量解决，而非切换队列。
> bigmem 队列仅因 extended 无法使用 bigmem 节点（Maui 隐式 [normal] feature）。

### 9.3 已知 bug

**Bug 1: C3v/C4v assertion error** — 只影响 **s12 模式**，不影响 ez。

**Bug 2: ModRat coprime error (Phase B Step3)** — 影响 ez 模式的群结构计算。

已确认受影响的 SG: **#22, #42**。两者具有相同特征：
- Phase A (分类) 完全正常，结果有效
- Phase B Step1 (ComponentEx) 正常完成
- Phase B Step3 (extension computation) 在 `ext layer 2 (p=2)` 崩溃
- 错误调用链: `SptSetSpecSeqResult` → `SptSetSpecSeqModuleClassToLeadingVector` (`ss_module.gi:502`)
  → `SptSetFpZModuleCanonicalElm` (`ss_module.gi:137`) → `vp[i] mod R[i][i]` (`module.gi:191`)
- 错误本质: `MapFromBarCocycle` 返回的向量在 `SptSetFpZModuleCanonicalElm` 中变成了 ModRat 类型，
  对 ModRat 做 `mod` 运算时分母与模数不互素
- **这是确定性 bug**，重试不会修复（SG#22 已重试 5 次，完全相同的错误）
- monitor.sh 已更新：
  - 检测 ModRat 错误后不再重复提交
  - 新增通用崩溃检测：通过 `=== Exit:` 标记判断是 bug 崩溃还是 walltime 中断，只重提交后者
  - 新增 `sg_crashed()` 函数和 `errored_sgs()` 通用崩溃扫描

### 9.4 提交顺序 ✅

1. 先提交三个最难的 (210, 219, 228) 到 bigmem 节点
2. 然后按空间群编号从小到大提交 (1, 2, 3, ...)
3. 每次提交填满可用节点即可，不需要大量排队
4. 根据前面 SG 的运行情况调整后续脚本

### 9.5 脚本方式 ✅

**预生成独立脚本**：每个 SG 有自己的 setup `.g` 文件和 PBS `.sh` 文件，方便调试。
不使用动态生成或批量提交脚本。手动分批提交，控制队列中保持一定数量。

### 9.6 并行配置 ✅

| 参数 | 普通 SG | 最难 3 个 SG |
|------|---------|-------------|
| SPTSET_PARALLEL_JOBS | 24 | 26 |
| SPTSET_PARALLEL_THRESHOLD | 10 | 5 |
| SPTSET_PHASE2_ENABLED | true | true |

最难 3 个群使用更激进的配置（26 workers / threshold 5），
SG#10 基准测试表明即使小群也能从低 threshold 中获得加速。

### 9.7 s12 模式

先完成 ez 模式。s12 后续再做，复用同样的基础设施。

---

## 10. 文件结构

```
space_group/
├── plan.md                     # 本文档
├── monitor.sh                  # 自动监控脚本（cron 每 5 分钟）
├── monitor.log                 # 监控日志
├── generate_batch.py           # 批量生成 setup + PBS 脚本
├── collect_results.sh          # 结果收集脚本（后续编写）
├── setup/                      # GAP setup 文件（每个 SG 一个）
│   ├── sg001.g                 # CKPT_SG_NUM := 1;; + 统一配置
│   ├── sg002.g
│   ├── ...
│   ├── sg210.g                 # JOBS=26, THRESHOLD=5
│   ├── sg219.g
│   └── sg228.g
├── pbs/                        # PBS 提交脚本（每个 SG 一个）
│   ├── sg001.sh                # extended 队列, 输出 → .log
│   ├── sg002.sh
│   ├── ...
│   ├── sg026.sh                # bigmem 队列, 输出 → .log
│   ├── sg210.sh                # extended 队列, 输出 → .log
│   └── sg228.sh
└── results/                    # 实时输出（.log）+ PBS 历史输出（.out/.err）
    ├── sg002.out               # 已完成任务的 PBS 输出
    ├── sg026.log               # 运行中任务的实时 log（新脚本）
    └── ...
```

每个 SG 对应两个文件:
- `setup/sgNNN.g`: 7 行 GAP 脚本，设置参数并调用 `checkpoint_driver.g`
- `pbs/sgNNN.sh`: ~30 行 csh PBS 脚本，输出直接写入 `.log` 文件

生成方式:
```bash
cd space_group/
python3 generate_batch.py 21 50              # extended 队列
python3 generate_batch.py 26 29 bigmem       # bigmem 队列
```

提交方式:
```bash
ssh head "cd ~/software/gap-4.13.1/pkg/SptSet && qsub space_group/pbs/sg210.sh"
```

---

## 11. 技术细节

### 11.1 GAP 工作目录

`checkpoint_driver.g` 内部使用 `Read("res_space_group.g")` (相对路径)，
该文件位于 `examples/` 目录。PBS 脚本中 cd 到 `examples/` 确保路径正确：

```csh
cd /home/user/xyren/software/gap-4.13.1/pkg/SptSet/examples
$GAP -q -r -b $SETUP
```

Setup `.g` 文件使用 `checkpoint_driver.g` 的**绝对路径**，避免路径依赖。

### 11.2 Checkpoint 文件

- 路径: `~/checkpoints/sgN.ws`（N 不补零, 由 checkpoint_driver.g 默认生成）
- PBS 脚本检查 checkpoint 文件存在性，决定 fresh start 还是 resume
- 原子写入（.tmp + mv）防止损坏

### 11.3 Job 命名

PBS job 名使用三位补零: `sg001`, `sg010`, `sg210`，便于 `showq` 中排序识别。

### 11.4 PBS 节点名格式

PBS 内部使用 FQDN 格式（如 `n01.local`），`pbsnodes` 也需要用 FQDN 查询。
不指定特定节点，由 PBS/Maui 自动分配：
- `#PBS -q extended -l nodes=1:ppn=28` → 分配 normal 节点
- `#PBS -q bigmem -l nodes=1:ppn=28` → 分配 bigmem 节点

---

## 12. 时间线估算 (2026-03-05 更新)

### 12.1 实测进度

6 天完成 59/230 (25.7%)。其中：
- Tier 0-1 (SG#2-9): 1h 内全部完成 ✅
- Tier 2 (SG#10-47): 8m-16.7h 不等，4 天内全部完成 ✅
- Tier 3 (SG#48-63): 2.1h-66h 不等，大部分已完成 ✅（SG#48/52 最慢各 ~66h）

**关键发现**: Step 4 (E^{1,3}\_5) 是 Phase A 的绝对瓶颈。
以 SG#48 为例: Step 4 = 59.6h / 总 65.9h = **90.4%**。
其中 `d2^{2,2}_3` (49.9h) >> `d2^{3,1}_2` (9.7h)。

### 12.2 修正估算 (2026-03-17 三次修正)

| 阶段 | 内容 | 预计时间 | 状态 |
|------|------|---------|------|
| Tier 0-1 (~16 个 SG) | 秒到分钟级 | 1h 全部完成 | ✅ 完成 |
| Tier 2 (SG#10-47) | 8m-16.7h | ~4 天 | ✅ 完成 |
| Tier 3 (SG#48-~100) | 2.1h-66h 每个 | ~1-2 周 | 🔄 大部分完成 |
| Tier 4 (~100-~200) | 预计 1d-2w 每个 | ~2-4 周 | ⏳ |
| Tier 5 (~200-230) | 预计 1w-1mo 每个 | ~1-2 月 | ⏳ |
| ~~SG #210 (3/5 估)~~ | ~~1-3 天~~ | — | ❌ 作废 |
| ~~SG #210fix (3/14 估)~~ | ~~fix 后 ~1-2 天~~ | — | ❌ **严重失准, 见 §12.6** |
| **SG #210fix (3/17 修正)** | Step 7 卡在 d2^{3,1}\_2 + d2^{2,2}\_3 | **~10-17 天** | 🔄 Step 7 运行中 |
| **SG #219fix (3/17 修正)** | 同上 | **~8-15 天** | 🔄 Step 7 运行中 |
| **SG #228fix (3/17 修正)** | 同上, dims 更大 | **~14-25 天** | 🔄 Step 7 运行中 |

普通 SG (Tier 3-4) 以平均每天 ~2 个的速度完成 (8 天 14 个)。

> ⚠️ **三次估算失准历程**:
> - **3/5 估算** (§12.5.4): 基于 SG#48 外推，未预见 per-gen 成本的巨大差异 → 严重低估
> - **3/14 估算** (§12.5.7): 认为 fix 消除了 d2^{2,2}\_3 → **错误**, d2^{2,2}\_3 实际推迟到 Step 7
> - **3/17 修正** (§12.6): 代码追踪发现 Step 7 的 psi 调用链触发了完整的 d2^{2,2}\_3 计算
>   fix 任务实际需要 **10-25 天**, 与旧任务总时间相当

### 12.3 ModRat bug 的影响

SG#22 和 SG#42 的分类已完成但群结构失败。需要修复 `module.gi:191` 后重新计算。
目前 84 个已完成 SG 中只有这 2 个触发 ModRat bug (2.4%)。
**ASSERTION FAILURE 警告**（"top layer is not a cocycle"）出现在 **9 个 SG**:
SG#30, 36, 41, 56, 60, 64, 68, 85, 90 — 非致命，全部正常完成并输出了正确群结构。
详细列表见附录 B.2b。
debug 环境已搭建完成 (`~/gap-debug/`，详见 `notes/debug_cluster.md`)。

### 12.4 节点利用率与 monitor 改进 (2026-03-14)

集群状况：xyren 当前 9 个任务运行中，2 个排队。
- monitor.sh **四层改进**：
  1. `cancel_stale_jobs()` — 取消已完成/已报错 SG 的僵尸排队作业
  2. `errored_sgs()` — 检测 ModRat/Resolution 模式错误 + 通用崩溃（有 Exit 无 ALL DONE）
  3. `sg_crashed()` — Step 5 重提交前的崩溃检查，只允许 walltime 中断重提交
  4. **Step 5 重提交一律 extended** — 有 checkpoint 说明 >60h，不再放回 bigmem 浪费时间
- **已确认失败**: 只有 SG#22, SG#42 (ModRat bug)，不会被重提交
- **ASSERTION FAILURE 警告**: SG#30, 36, 41, 56, 60, 64, 68, 85, 90 (共 9 个) — 非致命，全部正常完成
- SG#70 bigmem 排队任务已手动取消（已 resume 过），等 monitor 自动重提交到 extended
- SG#79, 80: 也已 resume 过但正在运行中，不取消；到期后 monitor 自动转 extended

### 12.5 ⚠️ 关键性能 Bug 发现与修复 (2026-03-14)

#### 12.5.1 Bug 描述

**文件**: `lib/ss_vanilla.gi`, `SptSetSpecSeqBuildComponent` 方法 (line ~76)

**问题**: 计算 E^{p,q}\_r 时，即使上一页 E^{p,q}\_{r-1} 已经是零（平凡），代码仍然
会继续计算当前页所需的所有微分（derivatives）。数学上 E^{p,q}\_{r-1} = 0 直接蕴含
E^{p,q}\_r = 0（以及之后所有 r' ≥ r 页），因此这些微分计算完全是浪费的。

**旧代码路径** (r ≥ 3 分支):

```gap
phi := SptSetSpecSeqDerivative(ss, r-1, p-(r-1), q+(r-1)-1);
psi := SptSetSpecSeqDerivative2(ss, r-1, p, q);
return SptSetHomologyModule(phi, psi);
```

旧代码直接计算 phi 和 psi 两个微分，然后求 homology。**没有检查**
`SptSetSpecSeqComponent(ss, r-1, p, q)` 是否为零——即使 homology 的结果必然为零。

#### 12.5.2 受影响的计算

**最严重的受害步骤: Phase A Step 4 (E^{1,3}\_5)**

Step 4 计算 E^{1,3}\_5 (p+ip 层第 5 页)。对于所有三个最难 SG (210/219/228),
E^{1,3}\_4 = 0 (在 Step 3 已确认)，因此 E^{1,3}\_5 必然为零。
但旧代码不检查这一点，仍然触发以下昂贵计算:

1. **d2^{3,1}\_2** — E^{3,1}\_2 到 E^{1,2}\_2 的微分
   - SG#73 实测: 25 gens × ~644s/gen = **16.1h**
   - 这个微分后续计算 E^{3,1}\_3 (Step 9) 时仍然需要，所以**不算完全浪费**
   - 只是被提前计算了（从 Step 9 提前到 Step 4）

2. **d2^{2,2}\_3** — E^{2,2}\_3 到 E^{0,4}\_3 的微分 (第 3 页微分)
   - SG#73 实测: 25 gens × ~23050s/gen = **160.1h** (= **6.7 天**)
   - **这个微分只被 E^{1,3}\_5 的计算需要**
   - 如果 E^{1,3}\_5 被跳过，d2^{2,2}\_3 **永远不会被任何其他步骤触发**
   - → **完全冗余，160h 纯浪费！**

#### 12.5.3 实证: SG#73 作为校准基准

SG#73 (空间群 Ibca, 点群 D\_2h, dims 1,7,25,63,129,231,375) 是第一个完成的
大型 Tier 5 空间群，提供了关键的性能数据:

| 阶段 | 时间 | 说明 |
|------|------|------|
| Resolution 构建 | 32,639s (9.1h) | ✅ |
| Phase A Steps 1-3 | 56,119s (15.6h) | ✅ |
| Phase A Step 4 (E^{1,3}\_5) | **665,508s (184.9h = 7.7 天)** | ❌ 完全浪费 |
| ↳ 其中 d2^{3,1}\_2 | 57,840s (16.1h) | 后续 Step 9 仍需 |
| ↳ 其中 d2^{2,2}\_3 | **576,268s (160.1h)** | ❌ **纯浪费** |
| Phase A Steps 5-14 | ~3,600s (~1h) | ✅ 快速 |
| Phase B | 进行中 | — |
| **Phase A 总计** | **725,227s (201.5h)** | — |
| **Phase A (如有 fix)** | **~59,719s (~16.6h)** | Step 4 瞬间完成 |
| **节省** | **~665,508s (184.9h)** | **Phase A 快 12x** |

**关键数据: d2^{2,2}\_3 vs d2^{3,1}\_2 的代价比**

| 微分 | gens | per-gen 时间 | 总时间 | 比例 |
|------|------|-------------|--------|------|
| d2^{3,1}\_2 (Step 4 提前, Step 9 正式) | 25 | ~644s | 16.1h | 1x |
| d2^{2,2}\_3 (仅 Step 4 需要, fix 后跳过) | 25 | ~23,050s | **160.1h** | **10x** |

d\_3 微分比 d\_2 微分贵 ~10x (更高阶差分，计算复杂度急剧增加)。

#### 12.5.4 为什么此前的时间预估严重失准

2026-03-05 做出的预估:
- SG#210: "即将完成，~2.6 天剩余" → **实际又跑了 11+ 天无任何输出**
- SG#219: "5-15 天" → **实际 11+ 天无进展**
- SG#228: "8-40 天" → **实际完全停滞**

**根本原因**: 3 月 5 日的分析只参考了 SG#48 (Tier 3) 的 Step 4 数据。
SG#48 Step 4 总计 59.6h (d2^{3,1}\_2=9.7h + d2^{2,2}\_3=49.9h)。
由于 SG#48 的 d2^{2,2}\_3 仅 49.9h (dims 较小),
据此外推到 dims 相同/接近的 SG#210 似乎合理。

**错误在于**: SG#48 的 per-gen 成本在不同 SG 之间变化巨大:
- SG#48 d2^{2,2}\_3: 18 gens × ~9,976s/gen = 49.9h
- SG#73 d2^{2,2}\_3: 25 gens × ~23,050s/gen = 160.1h
- 即使 SG#73 gens 更多 (25 vs 18), per-gen 成本也贵 **2.3x**
- 而 SG#73 的 dims (1,7,25,63,...) 比 SG#48 (1,6,18,38,...) 大得多

对于 SG#210/219/228，实际 d2^{2,2}\_3 的 per-gen 成本和 gens 数量完全未知,
预估的不确定性是**数量级级别**的，而不是之前假设的 ~2x 范围。

**但这一切都不重要了**: 因为 E^{1,3}\_4 = 0，d2^{2,2}\_3 **根本不需要计算**。

#### 12.5.5 修复方案

**修改**: `lib/ss_vanilla.gi`, `SptSetSpecSeqBuildComponent` 方法

```gap
    else
      # FIX: 如果上一页已经是零，当前页必然为零，跳过所有微分计算
      if SptSetFpZModuleIsZero(SptSetSpecSeqComponent(ss, r-1, p, q)) then
        return SptSetZeroModule();
      fi;
      phi := SptSetSpecSeqDerivative(ss, r-1, p-(r-1), q+(r-1)-1);
      psi := SptSetSpecSeqDerivative2(ss, r-1, p, q);
      return SptSetHomologyModule(phi, psi);
```

**数学正确性**: E^{p,q}\_{r-1} = 0 ⟹ E^{p,q}\_r = 0。
这是谱序列的基本性质：如果某一页的一个 entry 变成零，
所有后续页中该位置的 entry 都是零 (因为 E^{p,q}\_r 是 E^{p,q}\_{r-1} 的子商)。

**影响范围**: 只对 r ≥ 3 分支生效 (r = 2 分支计算 cokernel，不受影响)。
对所有空间群的所有步骤都有效——只要某一步的前一页为零，立即跳过。

#### 12.5.6 Fix 任务提交策略 (2026-03-14)

**原则**: 原始任务 (sg210/sg219/sg228) **绝对不碰**——保持运行。
另外提交三个 fix 任务并行跑，利用修复后的代码从 checkpoint 恢复。

**技术难点: GAP Workspace 包含旧代码**

GAP 的 SaveWorkspace 将整个运行环境序列化（包括所有已加载的函数定义）。
checkpoint_driver.g 在 resume 时检测 `IsBound(CKPT_STEP)`，
如果已绑定则跳过 `LoadPackage("SptSet")`。这意味着 workspace 中的
旧版 `SptSetSpecSeqBuildComponent` 会被使用，fix 不会生效。

**解决方案**: 在 fix setup 文件中，resume 后显式重新加载 `ss_vanilla.gi`:

```gap
if IsBound(CKPT_STEP) then
    Read("/home/user/xyren/software/gap-4.13.1/pkg/SptSet/lib/ss_vanilla.gi");;
    Print("*** ss_vanilla.gi reloaded (BuildComponent trivial-page fix active) ***\n");;
fi;;
```

GAP 的 InstallMethod 对同签名的新方法会覆盖旧方法（最后安装的优先级最高），
因此重新 Read 文件后新的 `SptSetSpecSeqBuildComponent` 会生效。

**Checkpoint 复制**:
- `~/checkpoints/sg210.ws` → `~/checkpoints/sg210fix.ws` (216MB)
- `~/checkpoints/sg219.ws` → `~/checkpoints/sg219fix.ws` (198MB)
- `~/checkpoints/sg228.ws` → `~/checkpoints/sg228fix.ws` (198MB)
- 原始 checkpoint 不受影响，原始任务继续使用原文件
- 复制的 checkpoint 包含 Steps 1-3 的所有缓存结果 (CKPT\_STEP = 3)

**PBS 任务配置**:

| 属性 | 值 |
|------|-----|
| 队列 | extended (INFINITY walltime) |
| 优先级 | `-p 1023` (PBS 用户最高优先级) |
| 节点 | 1 node × 28 ppn |
| 名称 | sg210fix / sg219fix / sg228fix |
| Setup 文件 | `setup/sg{210,219,228}fix.g` |
| Checkpoint | `~/checkpoints/sg{210,219,228}fix.ws` |
| Log 文件 | `results/sg{210,219,228}fix.log` |

**已提交 Job ID**:

| 任务 | Job ID | 队列 | 状态 |
|------|--------|------|------|
| sg210fix | 114260.head.local | extended | Q (排队) |
| sg219fix | 114261.head.local | extended | Q (排队) |
| sg228fix | 114262.head.local | extended | Q (排队) |

#### 12.5.7 ~~Fix 后时间预估~~ ❌ 已作废 (见 §12.6)

> ⚠️ **此节的分析和预估严重错误**, 已被 §12.6 (2026-03-17 修正) 取代。
>
> **错误核心**: 认为 d2^{2,2}\_3 "永远不会被计算"——实际上它只是从 Step 4 推迟到了 Step 7。
> 详见 §12.6 的完整代码追踪和修正分析。
>
> **后果**: 基于此错误分析，3/17 取消了原始 sg210/sg219/sg228 任务，
> 损失了 ~300h+ 的计算进度（原始任务的 d2^{2,2}\_3 已运行大半）。

### 12.6 ⚠️ Fix 效果修正分析 (2026-03-17) — 纠正 §12.5.7 的错误

#### 12.6.1 错误回顾

§12.5.7 (3/14) 声称:
- "d2^{2,2}\_3 **永远不会被计算**" — ❌ **错误**
- "Fix 任务预计总运行时间 ~1-3 天" — ❌ **严重低估**
- "d2^{2,2}\_3 **100% 节省**" — ❌ **错误**

**错误来源**: 只追踪了 Step 4 的调用链 (`E^{1,3}_5` → fix 跳过 → d2^{2,2}\_3 不触发)，
但**没有追踪 Step 7** (`E^{2,2}_4`) 的调用链。

#### 12.6.2 代码追踪: Step 7 为什么也需要 d2^{2,2}\_3

Step 7 计算 `E^{2,2}_4` (Majorana 层第 4 页)。调用 `SptSetSpecSeqBuildComponent(ss, 4, 2, 2)`:

```
r=4, p=2, q=2:
  检查 E^{2,2}_3 是否为零 → 一般不为零 → 继续
  phi = SptSetSpecSeqDerivative(ss, 3, -1, 4) → p-r+1 = -1 < 0 → zero map
  psi = SptSetSpecSeqDerivative2(ss, 3, 2, 2)
      → M = E^{2,2}_3  (已缓存)
      → N = SptSetSpecSeqComponent2(ss, 3, 5, 0) = E-tilde^{5,0}_3
          → E-tilde^{5,0}_3 需要 SptSetSpecSeqBuildComponent(ss, 3, 5, 0):
              → phi = d(ss, 2, 3, 1) = d2^{3,1}_2  ← 需要计算!
              → psi = d2(ss, 2, 5, 0) = d2^{5,0}_2  (一般为零)
          → 如果 E-tilde^{5,0}_3 非零:
              → 继续计算 d2^{2,2}_3 的映射 ← 也需要计算!
```

**关键发现**:
1. `E-tilde^{5,0}_3` 依赖 `d2^{3,1}_2` → Step 7 需要完整计算 d2^{3,1}\_2
2. 如果 `E-tilde^{5,0}_3` 非零（根据 sg073/sg090/sg091 经验，一般非零），
   则 psi 的计算需要 d2^{2,2}\_3 → Step 7 也需要完整计算 d2^{2,2}\_3
3. 这些计算与旧代码 Step 4 中被 "浪费" 的计算**完全相同**

#### 12.6.3 旧代码 vs Fix 代码的真正区别

| | 旧代码 | Fix 代码 |
|--|--------|---------|
| Step 4 | 计算 d2^{3,1}\_2 + d2^{2,2}\_3 (结果缓存, 但 E^{1,3}\_5 = 0) | **跳过** (fix early return) |
| Step 7 | 使用**缓存的** d2^{3,1}\_2 + d2^{2,2}\_3，瞬间完成 | **从零计算** d2^{3,1}\_2 + d2^{2,2}\_3 |
| **净效果** | d2^{2,2}\_3 在 Step 4 计算 | d2^{2,2}\_3 在 **Step 7** 计算 |
| **总时间** | **相同** (只是计算发生在不同 step) | **相同** |

**Fix 的真正收益**: 对于那些 `E-tilde^{5,0}_3 = 0` 的 SG (很少)，fix 确实消除了 d2^{2,2}\_3。
但对于 210/219/228 这三个最难的 SG，`E-tilde^{5,0}_3` 几乎必然非零，因此 fix 的实际加速**接近零**。

#### 12.6.4 取消原始任务的损失评估

| 任务 | 原始任务 Step 4 已运行 | Fix 任务 Step 7 已运行 | 净损失 |
|------|----------------------|---------------------|--------|
| SG#210 | ~345h (接近完成?) | ~30h | ~315h |
| SG#219 | ~300h | ~50h | ~250h |
| SG#228 | ~345h (接近完成?) | ~30h | ~315h |
| **合计** | — | — | **~880h (36.7 天)** |

旧任务计算同一个 d2^{2,2}\_3，只是在 Step 4 而非 Step 7。
如果没有取消，旧任务可能在数天内完成 Step 4，然后 Steps 5-14 + Phase B 使用缓存的
d2^{3,1}\_2 和 d2^{2,2}\_3 快速完成。

#### 12.6.5 修正后的时间预估

基于 SG#73 的实测数据 (d2^{3,1}\_2 ≈ 16h, d2^{2,2}\_3 ≈ 160h)
和 SG#90/91 的数据:

| SG # | d2^{3,1}\_2 预估 | d2^{2,2}\_3 预估 | Steps 5-14 合计 | Phase B | **总剩余** |
|------|-----------------|-----------------|----------------|---------|----------|
| 210fix | 25-50h | 200-350h | **225-400h** | ~1-24h | **~10-17 天** |
| 219fix | 25-50h | 150-300h | **175-350h** | ~1-24h | **~8-15 天** |
| 228fix | 50-100h | 250-500h | **300-600h** | ~1-24h | **~14-25 天** |

> **不确定性说明**: d2^{2,2}\_3 的 per-gen 成本在不同 SG 之间变化巨大
> (SG#48: 49.9h vs SG#73: 160.1h, 相差 3.2x)，以上估算仅供参考。
> 实际时间可能偏离一个数量级。**这就是不能基于预估取消任务的根本原因。**

#### 12.6.6 当前策略

1. **保持 fix 任务运行，绝不取消**。虽然损失了旧任务的进度，但取消 fix 重启旧任务更不划算
   (需要重做 resolution + Steps 1-6)。
2. **不要再做任何 "优化" 决策**。让任务自然完成。
3. **监控方式**: 每隔几天检查 checkpoint 时间戳和 CPU 使用率即可。
   长时间无日志输出是正常的 (Step 7 的 sub-computation 不写日志)。

---

## 附录 A: 依赖的关键文件

| 文件 | 作用 | 修改状态 |
|------|------|---------|
| `jobs/checkpoint_driver.g` | 核心计算 driver | 未修改（已完善） |
| `examples/res_space_group.g` | Resolution3DSpaceGroup 辅助函数 | 未修改 |
| `read.g` | 全局配置变量定义 | 未修改 |
| `lib/bar_resolution_map_common.gi` | Phase 1 并行 | 未修改 |
| `lib/ss_vanilla.gi` | AHSS 谱序列组件/微分计算 | **已修改 (2026-03-14)**: trivial-page early return fix, 详见 §12.5 |
| `lib/ss_module.gi` | Phase 2b 并行 + checkpoint | 未修改 |
| `setup/sg{210,219,228}fix.g` | Fix 任务 setup (显式重载 ss_vanilla.gi) | **新增 (2026-03-14)**, 详见 §12.5.6 |
| `pbs/sg{210,219,228}fix.sh` | Fix 任务 PBS 脚本 (extended, -p 1023) | **新增 (2026-03-14)** |

---

## 附录 B: 计算结果 (2026-03-17 更新)

### B.1 已完成 (84 个)

#### Tier 1: dims 1,4,7,8,8,8,8 (SG#2-9, 14m-1.2h)

| SG # | 总时间 | 群结构 (torsion) |
|------|--------|-----------------|
| 1 | ERROR | Resolution3DSpaceGroup 不支持平凡点群 |
| 2 | 3634s (1.0h) | [2,2,2,2,2,0,0,0] |
| 3 | 1507s (25m) | [4,8,8,8,0] |
| 4 | 4289s (1.2h) | [2,2,2,2,0] |
| 5 | 2264s (38m) | [2,4,8,0] |
| 6 | 857s (14m) | [4,8,0] |
| 7 | 3631s (1.0h) | [2,2,2,2,0] |
| 8 | 873s (15m) | [2,4,0] |
| 9 | 3028s (50m) | [2,2,2,0] |

#### Tier 2: dims 1,5,12,20,28,36,44 (SG#10-47, 8m-16.7h)

| SG # | 总时间 | 群结构 (torsion) |
|------|--------|-----------------|
| 10 | 10752s (3.0h) | [2,4,4,4,4,4,0] |
| 11 | 21564s (6.0h) | [2,4,0] |
| 12 | 12488s (3.5h) | [2,2,4,4,0] |
| 13 | 20370s (5.7h) | [2,4,8,0] |
| 14 | 42876s (11.9h) | [2,2,2,2,0] |
| 15 | 20084s (5.6h) | [2,2,4,0] |
| 16 | 762s (13m) | [2^12] |
| 17 | ~18000s (~5h) | 已完成 |
| 18 | 7196s (2.0h) | [2,4,8] |
| 19 | 19753s (5.5h) | [2,2,2] |
| 20 | 6168s (1.7h) | [2,4,8] |
| 21 | 1498s (25m) | [2,2,2,2,2,2,2,2,8] |
| 23 | 5894s (1.6h) | [2,2,2,2,2,2,2,2] |
| 24 | 60177s (16.7h) | [4,8,8] |
| 25 | 480s (8m) | [2,2,2,2,2,2,2,2] |
| 26 | 1545s (26m) | [2,2] |
| 27 | 2960s (49m) | [2,2,2,2] |
| 28 | 2888s (48m) | [4,8,8] |
| 29 | 12977s (3.6h) | [2,2,2,2] |
| 30 | 5645s (1.6h) | [2,4,8] |
| 31 | 4599s (1.3h) | [2,4] |
| 32 | 5880s (1.6h) | [2,4,8] |
| 33 | 12981s (3.6h) | [2,2,2] |
| 34 | 15899s (4.4h) | [2,4,8] |
| 35 | 1062s (18m) | [2,2,2,2,8] |
| 36 | 1569s (26m) | [2,2] |
| 37 | 3443s (57m) | [2,2,8] |
| 38 | 544s (9m) | [2,2,2,2] |
| 39 | 6887s (1.9h) | [2,2,2] |
| 40 | 2532s (42m) | [4,8] |
| 41 | 15309s (4.3h) | [2,2,4] |
| 43 | 46517s (12.9h) | [2,4] |
| 44 | 6065s (1.7h) | [2,2,2,2] |
| 45 | 38411s (10.7h) | [2,2,2] |
| 46 | 20780s (5.8h) | [2,8] |
| 47 | 3370s (56m) | [2^24] |

#### Tier 3: dims 1,6,18,38,66,102,146 (SG#48-63, 2.1h-66h)

| SG # | 总时间 | 群结构 (torsion) | Step 4 时间 | Phase B 时间 |
|------|--------|-----------------|-----------|------------|
| 48 | 237443s (**66.0h**) | [2^8] | 214489s (59.6h) | 46s |
| 49 | 7545s (2.1h) | [2^8,4] | 3450s (0.96h) | 1122s (19m) |
| 50 | 40239s (11.2h) | [2^8] | 37150s (10.3h) | 46s |
| 51 | 9741s (2.7h) | [2^4,4^2] | 5840s (1.6h) | 1253s (21m) |
| 52 | 236964s (**65.8h**) | [2,4,8] | 154295s (42.9h) | 8664s (2.4h) |
| 53 | 50737s (14.1h) | [2,4,4,8] | 38200s (10.6h) | 10056s (2.8h) |
| 54 | 27259s (7.6h) | [2,2,8] | 16600s (4.6h) | 8349s (2.3h) |
| 55 | 12824s (3.6h) | [2^2,4^2] | 8200s (2.3h) | 1288s (21m) |
| 56 | 114863s (31.9h) | [2^3] | 82000s (22.8h) | 29630s (8.2h) |
| 57 | 19178s (5.3h) | [2,8] | 12800s (3.6h) | 3410s (0.9h) |
| 58 | 54671s (15.2h) | [2^2,4^2] | 46900s (13.0h) | 4387s (1.2h) |
| 59 | 36858s (10.2h) | [2^4] | 34600s (9.6h) | 31s |
| 60 | 84122s (23.4h) | [2^2,4] | 57200s (15.9h) | 24199s (6.7h) |
| **61** | **441936s (122.8h = 5.1d)** | [2^4] | 171372s (47.6h) | 269204s (**74.8h = 3.1d**) |
| 62 | 71894s (20.0h) | [2^2] | 65800s (18.3h) | 3936s (1.1h) |
| 63 | 11069s (3.1h) | [2^2,4] | 6900s (1.9h) | 1245s (21m) |
| **64** | **149068s (41.4h)** | [2,2,4] | 103339s (28.7h) | 44806s (12.4h) |
| **65** | 4464s (1.2h) | [2^12,4] | 3269s (0.9h) | 991s (17m) |
| **66** | 8016s (2.2h) | [2^4,4^2] | 6639s (1.8h) | 1149s (19m) |
| **67** | 35170s (9.8h) | [2^7] | 32969s (9.2h) | 1766s (29m) |
| **68** | **103547s (28.8h)** | [2^2,2,4] | 75825s (21.1h) | 26990s (7.5h) |
| **69** | 47867s (13.3h) | [2^9] | 44041s (12.2h) | 3337s (56m) |
| **71** | 63050s (17.5h) | [2^12] | 62370s (17.3h) | 64s |
| **72** | **183332s (50.9h)** | [2^5] | 176745s (49.1h) | 5505s (1.5h) |
| **73** | **931067s (258.6h = 10.8d)** | [2^3] | 664933s (**184.7h = 7.7d**) | 227079s (**63.1h = 2.6d**) |
| **74** | **253421s (70.4h = 2.9d)** | [2^2,4^2] | 241387s (67.1h) | 10748s (3.0h) |

> **关键发现 (Tier 3 数据)**:
> - Step 4 (旧代码) 或 Step 7 (fix 代码) 是 Phase A 的绝对瓶颈: 占总时间的 **60-90%**
> - Step 4 的两个子计算: `d2^{3,1}_2` (较快) + `d2^{2,2}_3` (**极慢**)
> - `d2^{2,2}_3` (d_3 微分) 是 `d2^{3,1}_2` (d_2 微分) 的 **5-10x**
> - SG#73 (10.8 天) 远超其他 Tier 3，其中 Step 4 = 7.7 天, Phase B = 2.6 天
> - SG#61 (5.1 天) 也很长，其中 Phase B = 3.1 天（Phase B 也可能很慢！）
> - 计算时间变化仍然巨大 (1.2h ~ 10.8d)，取决于群的代数结构

#### 高编号 Tier 1 SG: dims 1,4,7,8,8,8,8 (SG#75-81, 2.2h-15.9h)

| SG # | 总时间 | 群结构 (torsion) | Step 4 时间 | Phase B 时间 |
|------|--------|-----------------|-----------|------------|
| 75 | 7769s (2.2h) | [2,8,8,8,0] | 2320s (0.6h) | 5077s (1.4h) |
| 76 | 57078s (15.9h) | [2,2,2,0] | 16859s (4.7h) | 40133s (11.1h) |
| 77 | 35587s (9.9h) | [4,8,8,0] | 11521s (3.2h) | 23326s (6.5h) |
| 78 | 57000s (15.8h) | [2,2,2,0] | 16828s (4.7h) | 40084s (11.1h) |
| 81 | 17357s (4.8h) | [2^4,8^3,0] | 3553s (1.0h) | 13685s (3.8h) |

> 这些 SG 的 resolution 维度与 SG#2-9 相同 (max dim=8)，但计算时间更长，
> 主要原因是 Phase B (群结构) 涉及更复杂的扩展计算。

#### 高编号 Tier 2 SG: dims 1,5,12,20,28,36,44 (SG#83,85, 14.4h-37.5h)

| SG # | 总时间 | 群结构 (torsion) | Step 4 时间 | Phase B 时间 |
|------|--------|-----------------|-----------|------------|
| 83 | 51920s (14.4h) | [2^2,2,4^2,8^2,0] | 18121s (5.0h) | 33653s (9.3h) |
| 85 | **134830s (37.5h)** | [2^2,8^2,0] | 48394s (13.4h) | 86142s (**23.9h**) |

> SG#85 的 Phase B 耗时 23.9h，是 Tier 2 中最慢的。

#### Tier 2.5: dims 1,6,18,37,60,84,108 (SG#89-99, 8m-22.3h)

| SG # | 总时间 | 群结构 (torsion) | Step 4 时间 | Phase B 时间 |
|------|--------|-----------------|-----------|------------|
| 89 | 1158s (19m) | [2^12] | 0s | 54s |
| 90 | **80155s (22.3h)** | [2^4,2,8] | 39936s (11.1h) | 37488s (10.4h) |
| 91 | 15275s (4.2h) | [4,8,8] | 7398s (2.1h) | 6877s (1.9h) |
| 93 | 2173s (36m) | [2^12] | 848s (14m) | 55s |
| 95 | 15246s (4.2h) | [4,8,8] | 7385s (2.1h) | 6862s (1.9h) |
| 97 | 4297s (1.2h) | [2^8] | 2063s (34m) | 41s |
| 99 | 496s (8m) | [2^6] | 0s | 32s |

> dims 1,6,18,37,60,84,108 (max dim=108) 介于 Tier 2 和 Tier 3 之间。
> 大多数 SG 在 2h 内完成，SG#90 是例外 (22.3h)。

### B.2 ModRat Bug (2 个) — Phase A 完成，Phase B 失败

| SG # | Phase A 状态 | Phase B 错误点 | 分类结果 |
|------|-------------|---------------|---------|
| 22 | ✅ 全部 14 步完成 | Step3 `ext layer 2 (p=2) gen 1/1 (torsion=2)` | E^{2,2}=[2], E^{4,0}=[2^8] |
| 42 | ✅ 全部 14 步完成 | Step3 `ext layer 2 (p=2) gen 1/1 (torsion=2)` | E^{2,2}=[2], E^{4,0}=[2,2] |

两者均为 resolution dims 1,5,12,20,28,36,44。错误是确定性的（见 §9.3 Bug 2）。
分类层级结果有效，群结构需要修复 `module.gi:191` 后才能计算。

### B.2b Assertion Warning: "top layer is not a cocycle" (9 个) — 非致命，全部正常完成

以下 SG 在计算过程中触发了 `"ASSERTION FAILURE: top layer is not a cocycle"` 警告，
但**均正常完成并输出了正确的群结构**。此警告是非致命的。

| SG # | dims | 总时间 | 群结构 (torsion) | 状态 |
|------|------|--------|-----------------|------|
| 30 | 1,5,12,20,28,36,44 | 5645s (1.6h) | [2,4,8] | ✅ 正常完成 |
| 36 | 1,5,12,20,28,36,44 | 1569s (26m) | [2,2] | ✅ 正常完成 |
| 41 | 1,5,12,20,28,36,44 | 15309s (4.3h) | [2,2,4] | ✅ 正常完成 |
| 56 | 1,6,18,38,66,102,146 | 114863s (31.9h) | [2^3] | ✅ 正常完成 |
| 60 | 1,6,18,38,66,102,146 | 84122s (23.4h) | [2^2,4] | ✅ 正常完成 |
| 64 | 1,6,18,38,66,102,146 | 149068s (41.4h) | [2,2,4] | ✅ 正常完成 |
| 68 | 1,6,18,38,66,102,146 | 103547s (28.8h) | [2^2,2,4] | ✅ 正常完成 |
| 85 | 1,5,12,20,28,36,44 | 134830s (37.5h) | [2^2,8^2,0] | ✅ 正常完成 |
| 90 | 1,6,18,37,60,84,108 | 80155s (22.3h) | [2^4,2,8] | ✅ 正常完成 |

> 之前 §12.3 提到 8 个 (30, 36, 41, 56, 60, 64, 68, 85)，SG#90 是新发现的第 9 个。
> 虽然结果正确，但此警告可能暗示某些内部数值精度问题，值得关注。

### B.3 运行中 (2026-03-17 最新)

**Extended 队列 (HARDEST, 3/6 slot — 原始任务已取消):**

| SG # | Job ID | 已运行 | 状态 |
|------|--------|--------|------|
| ~~**228**~~ | ~~114049~~ | ~~345h+~~ | ❌ **3/17 误取消**, 损失 ~345h d2^{2,2}\_3 进度 |
| ~~**210**~~ | ~~114091~~ | ~~345h+~~ | ❌ **3/17 误取消**, 损失 ~345h d2^{2,2}\_3 进度 |
| ~~**219**~~ | ~~114092~~ | ~~345h+~~ | ❌ **3/17 误取消**, 损失 ~300h d2^{2,2}\_3 进度 |
| **210fix** | 114263 | ~72h | Phase A **Step 7**/14, d2^{3,1}\_2 + d2^{2,2}\_3 中 |
| **219fix** | 114264 | ~72h | Phase A **Step 7**/14, 同上 |
| **228fix** | 114265 | ~72h | Phase A **Step 7**/14, 同上 |

> ⚠️ **3/17 取消原始任务的代价**: 原始任务 d2^{2,2}\_3 在 Step 4 已运行 ~300-345h，
> 接近完成。Fix 任务在 Step 7 从零开始同样的计算，目前仅运行 ~30-54h。
> 净损失约 300h 的计算进度。**这三个 fix 任务绝对不可再取消。**

**Long 队列 (13 个节点):**

当前有 13 个 long 任务在运行，3 个排队。已完成 73 个 SG，无新 error。

> **队列策略 (2026-03-17 修订)**: 原始 sg210/219/228 取消后释放 3 个 extended slot。
> Fix 任务占 3 个 extended slot。其余所有 SG 使用 long 队列。

### B.4 monitor.sh 改进历史

1. `cancel_stale_jobs()` — 取消已完成/已报错 SG 的僵尸排队作业
2. `sg_crashed()` + `errored_sgs()` 通用崩溃检测 — bug 崩溃不重提交，只重提交 walltime 中断
3. **Step 5 重提交一律用 extended** (2026-03-14) — 有 checkpoint 说明 bigmem 的 60h 不够，避免反复到期浪费时间

**历次完成数**: 59 (03-05) → 62 (03-06) → 76 (03-14) → **84 (03-17)**, 无新 ModRat 错误

4. **关键性能 Bug 修复** (2026-03-14) — `ss_vanilla.gi` trivial-page early return, 详见 §12.5
5. **Fix 任务提交** (2026-03-14) — sg210fix/sg219fix/sg228fix 提交到 extended, `-p 1023` 最高优先级
6. ⚠️ **原始 hardest 任务误取消** (2026-03-17) — 基于错误的 fix 效果分析，取消了
   原始 sg210/sg219/sg228 (已运行 300-345h)。损失 ~880h 合计计算时间。详见 §12.6
7. **Fix 效果分析修正** (2026-03-17) — d2^{2,2}\_3 **未被消除**，从 Step 4 推迟到 Step 7。
   fix 任务实际需要 10-25 天。**三个 fix 任务绝对不可再取消。** 详见 §12.6

### B.5 SG#228 复杂度精确分析

#### Scaling Exponent 拟合

利用 SG#228 与 SG#10 的实测数据，拟合 MapFromBarCocycle 的 scaling：

| 对比 | SG#10 | SG#228 | per-gen 时间比 | 拟合 exponent |
|------|-------|--------|---------------|--------------|
| Step 2 (d2^{1,3}\_2) | dim=20, 180ms/gen | dim=63, 33s/gen | 184x | **n^4.5** |
| Step 3 (d2^{2,2}\_2) | dim=28, 2.2s/gen | dim=129, 10924s/gen | 4966x | **n^5.6** |
| **平均** | — | — | — | **n^5.1** |

Phase B (ComponentEx) scaling 明显更温和：

| 对比 | SG#2 (dim=8) | SG#14 (dim=44) | 时间比 | exponent |
|------|-------------|---------------|--------|----------|
| Phase B 总时间 | 3003s | 28379s | 9.5x | **n^1.3** |

#### 与同级 SG 的对比 (2026-03-05 新增)

SG#228 step 3 d2^{2,2}\_2 (25 gens, dim=129) 只花了 **3.0h**，而 SG#48 (18 gens, dim=66) 花了 **15.1h**。
**SG#228 的 per-gen 成本仅为 SG#48 的 ~0.2x** — 尽管 dim 更高 (129 vs 66)！

这说明 O\_h 点群的代数结构对于 d\_2 微分计算实际上相当"便宜"。
但 SG#228 的 max dim = 375 (SG#48 的 2.57x)，高维的幂次放大效应可能抵消 per-gen 优势。

#### Step 4 预估 (~~2026-03-05~~ → 2026-03-14 修正)

旧预估 (已作废):

| 子计算 | 旧预估时间 | 结论 |
|--------|-----------|------|
| d2^{3,1}\_2 | 3-8 天 | ❌ 实际远超预估 (至少 13+ 天无输出) |
| d2^{2,2}\_3 | 5-30 天 | ❌ ~~fix 后完全跳过~~ → **实际在 Step 7 仍需计算** (见 §12.6) |
| d2^{1,3}\_4 | 跳过 | ✅ 这个预估是对的 |

**~~Fix 后 SG#228 预估~~ → 3/17 修正 (见 §12.6):**

| 阶段 | 时间 | 状态 |
|------|------|------|
| Resolution | 9.1h | ✅ (checkpoint 已含) |
| Phase A steps 1-6 | 数小时 | ✅ Steps 1-3 checkpoint, Step 4 fix 跳过, Steps 5-6 快速 |
| **Phase A step 7 (E^{2,2}\_4)** | **~250-500h** | 🔄 **真正瓶颈: d2^{3,1}\_2 + d2^{2,2}\_3** |
| Phase A steps 8-14 | 数小时 | ⏳ 缓存命中 |
| Phase B | ~2-24h | ⏳ |
| **fix 任务预计总剩余** | **~14-25 天** | Job 114265 |

> ⚠️ **3/17 修正**: d2^{2,2}\_3 并没有被 fix 消除，只是从 Step 4 推迟到 Step 7。
> 原始任务 (114049) 已于 3/17 误取消，损失了 ~345h d2^{2,2}\_3 计算进度。

### B.6 SG#210 精确分析 (2026-03-05 更新)

#### Resolution 特征

| 属性 | SG#210 | SG#228 (对比) | SG#48 (参考) |
|------|--------|-------------|-------------|
| 点群 | O (432), \|G\_pt\|=24 | O\_h (m-3m), \|G\_pt\|=48 | D2, \|G\_pt\|=4 |
| Resolution 构建时间 | **81,257s (22.6h)** | 32,639s (9.1h) | 44s |
| Resolution dims | 1,6,18,38,66,102,144 | 1,7,25,63,129,231,375 | 1,6,18,38,66,102,146 |
| max dim (deg 6) | 144 | 375 | 146 |

#### 当前进度 (2026-03-05)

| 步骤 | 结果 | 时间 | 状态 |
|------|------|------|------|
| Resolution | dims 1,6,18,38,66,102,144 | 81,257s (22.6h) | ✅ |
| Step 1: E^{1,3}\_2 | = [] (平凡!) | 64ms | ✅ |
| Step 2: E^{1,3}\_3 | = [] (平凡!) | 868ms | ✅ |
| Step 3: E^{1,3}\_4 | = [] | **56,822s (15.8h)** | ✅ |
| Step 4: E^{1,3}\_5 | d^{0,3}\_2 完成 (63ms) | 运行中 (2.6 天) | 🔄 |

#### 关键校准

SG#210 step 3 d2^{2,2}\_2: 18 gens, dim=66, **56,810s (15.8h)**。
SG#48 step 3 d2^{2,2}\_2: 18 gens, dim=66, **54,548s (15.1h)**。
→ **SG#210 ≈ SG#48 per-gen 成本** (1.05x)

由于 SG#210 与 SG#48 的 resolution dims 几乎相同 (144 vs 146) 且 per-gen 成本相当：
- SG#48 step 4 总计: 214,489s = **59.6h ≈ 2.5 天**
- SG#210 step 4 预估: ~62h ≈ **2.6 天** ← ❌ **严重失准，实际运行 >317h 仍未完成**

**失准原因**: SG#48 的 d2^{2,2}\_3 (49.9h) 只是该 SG 的情况。
SG#210 的 d2^{2,2}\_3 per-gen 成本未知，可能远大于 SG#48。

#### 时间估算 (2026-03-17 三次修正)

| 阶段 | 时间 | 状态 |
|------|------|------|
| Resolution | 22.6h | ✅ (checkpoint 已含) |
| Steps 1-3 | 15.8h | ✅ (checkpoint 已含) |
| Step 4 (fix) | < 1 秒 | ✅ fix 跳过 |
| Steps 5-6 | 数分钟~数小时 | ✅ 快速 |
| **Step 7 (E^{2,2}\_4)** | **~225-400h (10-17 天)** | 🔄 **d2^{3,1}\_2 + d2^{2,2}\_3** |
| Steps 8-14 | 数小时 | ⏳ 缓存命中 |
| Phase B | ~1-3h | ⏳ |
| **fix 任务预计总剩余** | **~10-17 天** | Job 114263 |

> ⚠️ 原始任务 (114091) 已于 3/17 误取消，损失 ~315h 计算进度。
> Fix 任务 Step 7 = 旧代码 Step 4 的同一计算 (d2^{2,2}\_3)，从零开始。详见 §12.6。

### B.7 SG#219 精确分析 (2026-03-05 新增)

#### Resolution 特征

| 属性 | SG#219 | SG#210 (对比) | SG#228 (对比) |
|------|--------|-------------|-------------|
| 点群 | T\_d (-43m), \|G\_pt\|=24 | O (432), \|G\_pt\|=24 | O\_h (m-3m), \|G\_pt\|=48 |
| Resolution 构建时间 | **29,954s (8.3h)** | 81,257s (22.6h) | 32,639s (9.1h) |
| Resolution dims | 1,6,18,38,66,102,144 | 1,6,18,38,66,102,144 | 1,7,25,63,129,231,375 |

> SG#219 与 SG#210 有**完全相同的 resolution dims**，但 resolution 构建快 2.7x。

#### 当前进度

| 步骤 | 结果 | 时间 | 状态 |
|------|------|------|------|
| Resolution | dims 1,6,18,38,66,102,144 | 29,954s (8.3h) | ✅ |
| Step 1: E^{1,3}\_2 | = **[2]** (非平凡!) | 72ms | ✅ |
| Step 2: E^{1,3}\_3 | = **[2]** (存活!) | 48,612ms | ✅ |
| Step 3: E^{1,3}\_4 | = [] | **46,007s (12.8h)** | ✅ |
| Step 4: E^{1,3}\_5 | — | 运行中 (2.2 天) | 🔄 |

#### 关键特征

**p+ip 层非平凡**: E^{1,3}\_2 = E^{1,3}\_3 = [2]，但在 page 4 被杀死 (E^{1,3}\_4 = [])。
与 SG#210 的关键区别:
- SG#219 step 3 d2^{2,2}\_2: 18 gens, dim=66, **10,270s (2.9h)** — 仅 SG#210 的 1/5.5
- SG#219 step 3 d2^{1,3}\_3: 1 gen, dim=66, **35,722s (9.9h)** — 额外的 d\_3 计算

**d\_2 便宜但 d\_3 贵**: SG#219 的 d\_3 微分 (9.9h/gen at dim=66) 远贵于 d\_2 (2.9h/18gens)。
这意味着 step 4 的 `d2^{2,2}_3` 可能比 SG#210 更慢。

#### 时间估算 (2026-03-17 三次修正)

| 阶段 | 时间 | 状态 |
|------|------|------|
| Resolution | 8.3h | ✅ (checkpoint 已含) |
| Steps 1-3 | 12.8h | ✅ (checkpoint 已含) |
| Step 4 (fix) | < 1 秒 | ✅ fix 跳过 |
| Steps 5-6 | 数分钟~数小时 | ✅ 快速 |
| **Step 7 (E^{2,2}\_4)** | **~175-350h (8-15 天)** | 🔄 **d2^{3,1}\_2 + d2^{2,2}\_3** |
| Steps 8-14 | 数小时 | ⏳ 缓存命中 |
| Phase B | ~1-3h | ⏳ |
| **fix 任务预计总剩余** | **~8-15 天** | Job 114264 |

> ⚠️ 原始任务 (114092) 已于 3/17 误取消，损失 ~250h 计算进度。
> SG#219 的 d\_3 较慢特性意味着 Step 7 的 d2^{2,2}\_3 可能特别慢。详见 §12.6。

---

## 附录 C: Maui Fair-Share 调度机制详解

### C.1 什么是 Fair-Share？

Maui 调度器使用 fair-share 策略平衡不同用户的资源使用：

- 每个用户有一个理想份额（target share）
- Maui 追踪每个用户的**历史 + 当前 + 排队中**的资源消费
- **超用** → `StartPriority` 降低 → 新任务排在后面
- **少用** → `StartPriority` 升高 → 新任务排在前面

### C.2 INFINITY Walltime 的毒性 ⚠️

**核心问题**：Maui 将**排队中未运行的任务**也计入预期资源需求。

对于 `extended` 队列（walltime = INFINITY）的排队任务：
- Maui 认为这个用户"打算"消耗 ∞ 资源
- fair-share 分数急剧下降
- `StartPriority` 变为负值（观测到 -15000+）
- 所有新提交的任务被标记为 **BLOCKED**，无法启动

**实际案例 (2026-03-01)**：
排队 6 个 INFINITY walltime 的 extended 任务后，所有 bigmem 队列任务被 BLOCKED，
4 个 bigmem 节点 (n01-n04) 空闲无法使用。取消 INFINITY 任务后立即恢复。

### C.3 症状识别

```bash
# 1. 查看任务 priority（负数 = fair-share 惩罚）
ssh head 'checkjob <JOB_ID>'
# 看 StartPriority 字段

# 2. 查看 fair-share 整体状态
ssh head 'diagnose -f -v | grep xyren'
# FSFactor 接近 0 或为负 → 严重惩罚

# 3. 查看被阻塞的任务
ssh head 'showq -b'
# BLOCKED 任务无法启动

# 4. 观察 idle 任务长时间不启动（即使有空闲节点）
ssh head 'showq -u xyren'
```

### C.4 根本解决方案

1. **所有任务使用 extended (INFINITY)**，每个任务跑到自然结束不打断
   - bigmem 队列仅用于 bigmem 节点（extended 无法访问 bigmem 节点）

2. **滴灌式排队控制** — monitor.sh 每 5 分钟执行一次
   - 非 hardest 的 extended idle 最多 **1 个**
   - bigmem idle 最多 **2 个**
   - 完成一个，自动补一个新的
   - 排队少 → Maui 看到的未来资源需求小 → priority 健康

3. **多余的自动取消**
   - 如果非 hardest 的 extended idle > 1（比如手动多提交了），自动取消多余的
   - hardest SG (210/219/228) **绝不取消**

4. **hardest SG 绝对保护**（见 §6.4）
   - 不取消、不删 checkpoint、不修改
   - monitor.sh 通过限制其他任务的排队来间接保证 hardest 的优先级

### C.5 诊断命令速查

| 命令 | 用途 |
|------|------|
| `ssh head 'showq -u xyren'` | 查看所有任务状态和 INFINITY 标记 |
| `ssh head 'checkjob <ID>'` | 查看单个任务的 priority/features |
| `ssh head 'diagnose -f'` | 查看 fair-share 分数 |
| `ssh head 'diagnose -p'` | 查看 priority 策略详情 |
| `ssh head 'showq -b'` | 查看被阻塞的任务列表 |
| `./monitor.sh --status` | 快速查看整体状态 |

### C.6 紧急恢复步骤

如果发现任务大面积 BLOCKED：

```bash
# 1. 查看哪些 INFINITY 任务在排队
ssh head 'showq -u xyren'

# 2. 取消所有非 hardest 的 extended idle 任务
# (monitor.sh 会自动做这个，也可手动)
ssh head 'qdel <JOB_ID>'

# 3. 等待 ~30 秒让 Maui 更新 priority
sleep 30

# 4. 确认被阻塞的任务已恢复
ssh head 'showq -u xyren'

# 5. 或者直接运行 monitor.sh，它会自动处理
./monitor.sh
```
