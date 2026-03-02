# 230 空间群系统计算计划

**状态: 运行中 (2026-03-02 更新) | 已完成 43/230 | ModRat bug 2个 | monitor.sh 自动管理中**

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

### 3.4 当前节点使用情况 (2026-03-02 12:00)

| 节点 | 占用者 | 任务 | 队列 | 备注 |
|------|--------|------|------|------|
| n01 (bigmem) | xyren | SG#22* | bigmem (60h) | *ModRat bug，将失败 |
| n02 (bigmem) | xyren | SG#49 | bigmem (60h) | Phase A step 4 运行中 |
| n03 (bigmem) | xyren | SG#42* | bigmem (60h) | *ModRat bug，将失败 |
| n04 (bigmem) | xyren | SG#48 | bigmem (60h) | Phase A step 4 运行中 |
| n05-n14 | cchen/ybli | — | extended | 其他用户占用 |
| n15 | xyren | **SG#228** | extended | Phase A step 4 运行中 (37h/~8d) |
| n17 | xyren | **SG#210** | extended | Phase A step 3 开始 |

排队中：SG#219 (extended), SG#17 (extended), SG#50 (bigmem)。

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

### 6.1 双队列策略

所有任务使用 INFINITY walltime，每个 SG 只跑一次不打断：

| 队列 | 用途 | walltime | 节点类型 | 说明 |
|------|------|---------|---------|------|
| **extended** | 所有 SG | INFINITY | normal (n05-n17) | 默认队列 |
| **bigmem** | 利用 bigmem 节点的 SG | 60h | bigmem (n01-n04) | 仅因 extended 无法用 bigmem 节点 |

**不使用 normal 队列**。extended 的 INFINITY walltime 保证每个任务不被中断。
Maui fair-share 问题通过 monitor.sh **控制排队数量**解决，而不是换队列。
bigmem 队列的 60h 限制由 checkpoint + monitor.sh 自动重启处理。

### 6.2 脚本生成

使用 `generate_batch.py` 批量生成：

```bash
cd space_group/

# 生成 SG#21-50 到 extended 队列
python3 generate_batch.py 21 50

# 生成 SG#26-29 到 bigmem 队列
python3 generate_batch.py 26 29 bigmem
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
1. **滴灌式补充 extended**：非 hardest 的 extended idle 最多 1 个，完成一个再补一个
2. 维持 bigmem 2 个 idle（充分利用 bigmem 节点）
3. 多余的非 hardest extended idle 自动取消（防止 fair-share 崩溃）
4. 检测中断的任务（有 checkpoint 但不在 PBS）并重新提交到 extended
5. 清理已完成 SG 的 checkpoint（**绝不删除 210/219/228 的 checkpoint**）

### 6.4 三个最难空间群 — 绝对保护规则 ⚠️

SG #210/219/228 使用 extended 队列 + normal 节点，INFINITY walltime。

**以下规则任何情况下都不可违反：**

| 规则 | 说明 |
|------|------|
| ❌ 禁止取消 | 任何情况下不得 qdel 这三个任务 |
| ❌ 禁止删除 checkpoint | **即使计算完成也不删除** checkpoint 文件 |
| ❌ 禁止修改脚本 | 运行中不得修改 setup/pbs 文件 |
| ❌ 禁止重新提交 | 除非确认任务已不在 PBS 中（crash/节点故障） |
| ✅ 最高优先级 | monitor.sh 通过控制其他任务的排队数量保证优先级 |
| ✅ 持续监控 | 定期检查 .log 和 checkpoint 时间戳确认存活 |

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
- 非 hardest SG → `extended` 队列（INFINITY）或 `bigmem` 队列（60h）
- hardest SG (210/219/228) → `extended` 队列（INFINITY）
- bigmem 60h 到期 → checkpoint 保护进度，monitor 自动重新提交恢复
- **错误检测**: monitor.sh 检测 ModRat 和 Resolution 错误，不重复提交已知 bug 的 SG

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
- monitor.sh 已更新，检测 ModRat 错误后不再重复提交

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

## 12. 时间线估算 (2026-03-02 更新)

### 12.1 实测进度

4 天完成 43/230 (18.7%)。其中：
- Tier 0-1 (SG#2-9): 1h 内全部完成 ✅
- Tier 2 (SG#10-47): 8m-16.7h 不等，4 天内大部分完成 ✅
- Tier 3+ (SG#48-): 刚进入，dims 1,6,18,38,66,102,146

### 12.2 修正估算

| 阶段 | 内容 | 预计时间 | 状态 |
|------|------|---------|------|
| Tier 0-1 (~16 个 SG) | 秒到分钟级 | 1h 全部完成 | ✅ 完成 |
| Tier 2 (SG#10-47) | 8m-16.7h | ~4 天 | ✅ 大部分完成 |
| Tier 3 (SG#48-~100) | 预计 1h-3d 每个 | ~1-2 周 | 🔄 进行中 |
| Tier 4 (~100-~200) | 预计 1d-2w 每个 | ~2-4 周 | ⏳ |
| Tier 5 (~200-230) | 预计 1w-1mo 每个 | ~1-2 月 | ⏳ |
| **SG #210** | 估计 1-4 周总计 | **0-14 天剩余** | 🔄 Phase A step 3 |
| **SG #219** | 估计 1-4 周总计 | 尚未开始 (排队中) | ⏳ |
| **SG #228** | 估计 37-56 天总计 | **32-52 天剩余** | 🔄 Phase A step 4 |

除三个最难外，其余 227 个预计 **2-3 个月内** 全部完成。
SG#210 可能在 1-2 周内完成。SG#228 需要 **1.2-1.9 个月**。

### 12.3 ModRat bug 的影响

SG#22 和 SG#42 的分类已完成但群结构失败。需要修复 `module.gi:191` 后重新计算。
后续可能有更多 SG 触发此 bug。当前仅影响 2/45 = 4.4%。

---

## 附录 A: 依赖的关键文件

| 文件 | 作用 | 需要修改？ |
|------|------|-----------|
| `jobs/checkpoint_driver.g` | 核心计算 driver | 否（已完善） |
| `examples/res_space_group.g` | Resolution3DSpaceGroup 辅助函数 | 否 |
| `read.g` | 全局配置变量定义 | 否 |
| `lib/bar_resolution_map_common.gi` | Phase 1 并行 | 否 |
| `lib/ss_vanilla.gi` | Phase 2 并行 | 否 |
| `lib/ss_module.gi` | Phase 2b 并行 + checkpoint | 否 |

所有核心代码已就位，本计划只需要新增 PBS 脚本。

---

## 附录 B: 计算结果 (2026-03-02 更新)

### B.1 已完成 (43 个)

| SG # | 总时间 | 群结构 (torsion) | Resolution dims |
|------|--------|-----------------|----------------|
| 1 | ERROR | — | Resolution3DSpaceGroup 不支持平凡点群 |
| 2 | 3634s (1.0h) | [2,2,2,2,2,0,0,0] | 1,4,7,8,8,8,8 |
| 3 | 1507s (25m) | [4,8,8,8,0] | 1,4,7,8,8,8,8 |
| 4 | 4289s (1.2h) | [2,2,2,2,0] | 1,4,7,8,8,8,8 |
| 5 | 2264s (38m) | [2,4,8,0] | 1,4,7,8,8,8,8 |
| 6 | 857s (14m) | [4,8,0] | 1,4,7,8,8,8,8 |
| 7 | 3631s (1.0h) | [2,2,2,2,0] | 1,4,7,8,8,8,8 |
| 8 | 873s (15m) | [2,4,0] | 1,4,7,8,8,8,8 |
| 9 | 3028s (50m) | [2,2,2,0] | 1,4,7,8,8,8,8 |
| 10 | 10752s (3.0h) | [2,4,4,4,4,4,0] | 1,5,12,20,28,36,44 |
| 11 | 21564s (6.0h) | [2,4,0] | 1,5,12,20,28,36,44 |
| 12 | 12488s (3.5h) | [2,2,4,4,0] | 1,5,12,20,28,36,44 |
| 13 | 20370s (5.7h) | [2,4,8,0] | 1,5,12,20,28,36,44 |
| 14 | 42876s (11.9h) | [2,2,2,2,0] | 1,5,12,20,28,36,44 |
| 15 | 20084s (5.6h) | [2,2,4,0] | 1,5,12,20,28,36,44 |
| 16 | 762s (13m) | [2^12] | 1,5,12,20,28,36,44 |
| 18 | 7196s (2.0h) | [2,4,8] | 1,5,12,20,28,36,44 |
| 19 | 19753s (5.5h) | [2,2,2] | 1,5,12,20,28,36,44 |
| 20 | 6168s (1.7h) | [2,4,8] | 1,5,12,20,28,36,44 |
| 21 | 1498s (25m) | [2,2,2,2,2,2,2,2,8] | 1,5,12,20,28,36,44 |
| 23 | 5894s (1.6h) | [2,2,2,2,2,2,2,2] | 1,5,12,20,28,36,44 |
| 24 | 60177s (16.7h) | [4,8,8] | 1,5,12,20,28,36,44 |
| 25 | 480s (8m) | [2,2,2,2,2,2,2,2] | 1,5,12,20,28,36,44 |
| 26 | 1545s (26m) | [2,2] | 1,5,12,20,28,36,44 |
| 27 | 2960s (49m) | [2,2,2,2] | 1,5,12,20,28,36,44 |
| 28 | 2888s (48m) | [4,8,8] | 1,5,12,20,28,36,44 |
| 29 | 12977s (3.6h) | [2,2,2,2] | 1,5,12,20,28,36,44 |
| 30 | 5645s (1.6h) | [2,4,8] | 1,5,12,20,28,36,44 |
| 31 | 4599s (1.3h) | [2,4] | 1,5,12,20,28,36,44 |
| 32 | 5880s (1.6h) | [2,4,8] | 1,5,12,20,28,36,44 |
| 33 | 12981s (3.6h) | [2,2,2] | 1,5,12,20,28,36,44 |
| 34 | 15899s (4.4h) | [2,4,8] | 1,5,12,20,28,36,44 |
| 35 | 1062s (18m) | [2,2,2,2,8] | 1,5,12,20,28,36,44 |
| 36 | 1569s (26m) | [2,2] | 1,5,12,20,28,36,44 |
| 37 | 3443s (57m) | [2,2,8] | 1,5,12,20,28,36,44 |
| 38 | 544s (9m) | [2,2,2,2] | 1,5,12,20,28,36,44 |
| 39 | 6887s (1.9h) | [2,2,2] | 1,5,12,20,28,36,44 |
| 40 | 2532s (42m) | [4,8] | 1,5,12,20,28,36,44 |
| 41 | 15309s (4.3h) | [2,2,4] | 1,5,12,20,28,36,44 |
| 43 | 46517s (12.9h) | [2,4] | 1,5,12,20,28,36,44 |
| 44 | 6065s (1.7h) | [2,2,2,2] | 1,5,12,20,28,36,44 |
| 45 | 38411s (10.7h) | [2,2,2] | 1,5,12,20,28,36,44 |
| 46 | 20780s (5.8h) | [2,8] | 1,5,12,20,28,36,44 |
| 47 | 3370s (56m) | [2^24] | 1,5,12,20,28,36,44 |

> **观察**: 所有 SG#2-9 的 resolution dims 为 1,4,7,8,8,8,8 (Tier 1，分钟级)；
> SG#10-47 (除 17) 的 resolution dims 为 1,5,12,20,28,36,44 (Tier 2-3，分钟到 16h)。
> 计算时间变化范围极大 (480s ~ 60177s)，取决于群的具体代数结构，而非仅仅 resolution 维度。

### B.2 ModRat Bug (2 个) — Phase A 完成，Phase B 失败

| SG # | Phase A 状态 | Phase B 错误点 | 分类结果 |
|------|-------------|---------------|---------|
| 22 | ✅ 全部 14 步完成 | Step3 `ext layer 2 (p=2) gen 1/1 (torsion=2)` | E^{2,2}=[2], E^{4,0}=[2^8] |
| 42 | ✅ 全部 14 步完成 | Step3 `ext layer 2 (p=2) gen 1/1 (torsion=2)` | E^{2,2}=[2], E^{4,0}=[2,2] |

两者均为 resolution dims 1,5,12,20,28,36,44。错误是确定性的（见 §9.3 Bug 2）。
分类层级结果有效，群结构需要修复 `module.gi:191` 后才能计算。

### B.3 运行中 (2026-03-02 12:00)

| SG # | 节点 | 队列 | 状态 | 进度 |
|------|------|------|------|------|
| 228 | n15 | extended | Phase A step 4/14 | d2^{3,1}\_2 运行中 (~25h/~8d) |
| 210 | — | extended | Phase A step 3/14 | Resolution 已完成 (22.6h)，步骤 1-2 秒级完成 |
| 48 | n04 | bigmem | Phase A step 4/14 | Resolution 44s, dims 1,6,18,38,66,102,146 |
| 49 | n02 | bigmem | Phase A step 4/14 | Resolution 12s, dims 1,6,18,38,66,102,146 |
| 22* | n01 | bigmem | Phase B Step3 | **将再次触发 ModRat bug** (monitor 已修复) |
| 42* | n03 | bigmem | Phase B Step3 | **将再次触发 ModRat bug** (monitor 已修复) |

> *SG#22/42 当前正在运行的是 monitor 修复前提交的，会再次崩溃。修复后不会再重复提交。

### B.4 排队中

- **Extended Idle**: SG#219 (hardest, INFINITY), SG#17 (normal, INFINITY)
- **Bigmem Idle**: SG#50
- monitor.sh 自动滴灌式补充

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

#### Step 4 逐子计算预估

| 子计算 | gens | target\_dim | 预估时间 | 说明 |
|--------|------|-----------|---------|------|
| d2^{3,1}\_2 | 63 | 231 | **~8 天** | 3 batches x 26 workers |
| d2^{2,2}\_3 | ~15 (估) | 231 | **~22 天** | 若 0 gens 则跳过 |
| d2^{1,3}\_4 | 0 | — | **跳过** | E^{1,3}\_4 = [] |

Step 4 总计：**8-30 天**（取决于 d2^{2,2}\_3 的 gen 数）

#### 总时间预估 (2026-03-02 更新)

| 阶段 | 时间 | 状态 |
|------|------|------|
| Resolution | 9.1h | ✅ 完成 |
| Phase A steps 1-3 | 3.5h | ✅ 完成 |
| Phase A step 4 | ~8-30 天 | 🔄 运行中 (~25h/~8d for d2^{3,1}\_2) |
| Phase A steps 5-14 | 1 天 - 2 周 | ⏳ |
| Phase B | ~6 天 (n^1.3 scaling) | ⏳ |
| **总计** | **~37-56 天 (1.2-1.9 月)** | — |
| **已用** | **~37h** | 2026-02-28 22:58 开始 |
| **预计剩余** | **~32-52 天** | — |

> **关键里程碑**: Step 4 的第一个输出行（d2^{3,1}\_2 完成）预计 **~3 月 9 日** 出现。
> 届时可精确校准 n^5.1 exponent，大幅缩小估算范围。
> 当前进度正常 — step 4 已运行 ~25h（d2^{3,1}\_2 的 63 gens 以 26 workers 并行处理中），
> checkpoint 自 step 3 完成后未更新属预期行为（单个大并行批次无中间保存点）。

### B.6 SG#210 复杂度分析 (新增 2026-03-02)

#### Resolution 特征

| 属性 | SG#210 | SG#228 (对比) | SG#10 (对比) |
|------|--------|-------------|-------------|
| 点群 | O (432), \|G\_pt\|=24 | O\_h (m-3m), \|G\_pt\|=48 | C2h, \|G\_pt\|=4 |
| Resolution 构建时间 | **81,257s (22.6h)** | 32,639s (9.1h) | 3,578ms (4s) |
| Resolution dims | 1,6,18,38,66,102,144 | 1,7,25,63,129,231,375 | 1,5,12,20,28,36,44 |
| max dim (deg 6) | 144 | 375 | 44 |

> **异常**: SG#210 的 resolution 构建时间 (22.6h) 是 SG#228 (9.1h) 的 2.5 倍，
> 但 resolution 维度却更小 (144 vs 375)。这说明 resolution 构建复杂度取决于点群的代数结构，
> 而非最终维度。点群 O (纯旋转) 的 non-symmorphic 构造比 O\_h (含反演) 更复杂。

#### 当前进度

| 步骤 | 结果 | 时间 | 状态 |
|------|------|------|------|
| Resolution | dims 1,6,18,38,66,102,144 | 81,257s (22.6h) | ✅ 完成 |
| Step 1: E^{1,3}\_2 | = [] (平凡!) | 64ms | ✅ |
| Step 2: E^{1,3}\_3 | = [] (平凡!) | 868ms | ✅ |
| Step 3: E^{1,3}\_4 | d2^{2,2}\_2 运行中 | — | 🔄 |

#### 关键观察

**p+ip 层完全平凡**: E^{1,3}\_2 = E^{1,3}\_3 = []，很可能 E^{1,3}\_∞ = []。
这意味着 steps 1-4 中的 p+ip 相关计算大幅简化。

#### 时间估算

SG#48/49 与 SG#210 有几乎相同的 resolution dims (1,6,18,38,66,102,146 vs 144)，
可作为最佳参考。注意 SG#48/49 的 resolution 构建仅需秒级 (44s/12s)，而 SG#210 需 22.6h。
但 AHSS 步骤的计算时间取决于 resolution 维度，而非构建时间。

从已完成的 dim=44 组 (SG#10-47) 数据来看：
- 最快: SG#38 = 544s (9m)
- 最慢: SG#24 = 60,177s (16.7h)
- Phase A step 4 (主瓶颈): d2^{2,2}\_3 时间从 427s 到 30,395s 不等

维度放缩 (dim 44 → 144, 比率 3.3x):
- 使用 n^5.1 scaling: 3.3^5.1 ≈ 430x — 但这是逐生成元的 scaling，不是总时间
- 实际放缩受并行度 (26 workers) 和生成元数量影响

| 场景 | Phase A + B 估算 | 总计 (含 resolution) |
|------|----------------|---------------------|
| 乐观 (类似 SG#49，多数层平凡) | 1-2 天 | **2-3 天** |
| 中等 (类似 SG#48) | 3-7 天 | **4-8 天** |
| 悲观 (复杂代数结构) | 1-3 周 | **2-4 周** |

> **vs SG#228**: SG#210 的 max resolution dim (144) 仅为 SG#228 (375) 的 38%。
> 以 n^5.1 scaling 估算，SG#210 的逐步计算应比 SG#228 快约 **130x**。
> 即使考虑最坏情况，SG#210 也应该比 SG#228 早数周完成。
>
> **预计完成**: 从当前算起 **1-14 天内**（中值约 5 天）。

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
