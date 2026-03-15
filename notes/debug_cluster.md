# SptSet Debug 环境：集群调试方案

**日期: 2026-03-02**
**状态: 环境就绪，调试进行中**

## 1. 背景

在系统性计算 230 个空间群的过程中，发现 SG#22 和 SG#42 在 Phase B Step3 (extension computation) 触发确定性 bug。后续还需要调试 s12 模式相关问题。

集群上有大量生产任务正在运行（SG#228/210/219 等 hardest 群，以及 monitor.sh 自动管理的普通群），**任何调试操作都不能影响生产流程**。

需要一个完全隔离的 debug 环境，在 cluster3 (login node) 上快速迭代测试。

## 2. 当前 Bug: ModRat coprime error

### 2.1 症状

Phase A (分类) 完全正常完成，Phase B Step3 (extension) 崩溃：

```
Error, ModRat: for <r>/<s> mod <n>, <s>/gcd(<r>,<s>) and <n> must be coprime in
  vp[i] mod R[i][i]
  at lib/module.gi:191
```

触发点：`ext layer 2 (p=2) gen 1/1 (torsion=2)` — Majorana 层 extension。

### 2.2 调用链

```
checkpoint_driver.g:165
  SptSetSpecSeqResult(CKPT_SS, 4, [1,2,3,4])
    ↓ ss_module.gi:495-502 — Step3 extension loop
    cjn := SptSetSpecSeqModuleVectorToClass(Exs[pi], tj * Exs[pi]!.generators[j])
    vjnf := SptSetSpecSeqModuleClassToLeadingVector(Exs[pj], cjn)     ← 这里触发
      ↓ ss_module.gi:134
      v := SptSetMapFromBarCocycle(ss!.brMap, p, spectrum, cl!.cochain!.layers[p+1])
      return SptSetFpZModuleCanonicalElm(M!.components[p], v) * M!.vector_embedings[p]
        ↓ module.gi:176-195 — SptSetFpZModuleCanonicalElm
        vp := v * P;               ← v 经过投影后变成了 ModRat 类型
        vp[i] := vp[i] mod R[i][i]; ← ModRat mod integer 触发 coprime 错误
```

### 2.3 涉及文件

| 文件 | 行号 | 函数 | 角色 |
|------|------|------|------|
| `lib/module.gi` | 176-195 | `SptSetFpZModuleCanonicalElm` | **崩溃点** — `vp[i] mod R[i][i]` |
| `lib/ss_module.gi` | 120-138 | `SptSetSpecSeqModuleClassToLeadingVector` | 调用者 — 传入 MapFromBarCocycle 的结果 |
| `lib/ss_module.gi` | 485-520 | `SptSetSpecSeqResult` (Step3 loop) | 触发 extension 计算 |

### 2.4 受影响的空间群

| SG # | Point group | Resolution dims | nGens [p+ip,Maj,CF,Bos] | Phase A | Phase B |
|------|------------|----------------|------------------------|---------|---------|
| 22 | D₂ (F222) | 1,5,12,20,28,36,44 | [0, 1, 0, 8] | ✅ 100 min | ❌ Step3 崩溃 |
| 42 | C₂ᵥ (Fmm2) | 1,5,12,20,28,36,44 | [0, 1, 0, 2] | ✅ 112 min | ❌ Step3 崩溃 |

确定性 bug — SG#22 已重试 5 次，SG#42 重试 4 次，每次完全相同的错误。

**从 checkpoint 恢复到崩溃的时间** (计算节点, 24 workers):
- SG#22: ~50 min/次
- SG#42: ~70 min/次

### 2.5 Bug 触发条件分析

对比同族 F-centered 正交群 (均有相同 resolution dims 1,5,12,20,28,36,44):

| SG# | Point group | nGens [p+ip,Maj,CF,Bos] | CF层 | Step3 结果 | Group structure |
|-----|------------|-------------------------|------|-----------|-----------------|
| 22 | D₂ | [0, **1**, **0**, 8] | trivial | ❌ CRASH | — |
| 23 | I222 | [0, 0, 0, 8] | trivial | ✅ (无ext) | Z₂⁸ |
| 25 | Pmm2 | [0, 0, 0, 8] | trivial | ✅ (无ext) | Z₂⁸ |
| 40 | Ama2 | [0, **1**, **2**, 2] | 2 gens | ✅ | Z₄×Z₈ |
| 41 | Aea2 | [0, **2**, **1**, 1] | 1 gen | ✅ | Z₂²×Z₄ |
| 42 | C₂ᵥ | [0, **1**, **0**, 2] | trivial | ❌ CRASH | — |
| 43 | Fdd2 | [0, **1**, **1**, 1] | 1 gen | ✅ | Z₂×Z₄ |
| 44 | Imm2 | [0, 0, 0, 4] | trivial | ✅ (无ext) | Z₂⁴ |
| 45 | Iba2 | [0, **2**, **1**, 0] | 1 gen | ✅ | Z₂³ |
| 46 | Ima2 | [0, **1**, **2**, 1] | 2 gens | ✅ | Z₂×Z₈ |

**关键发现: 崩溃当且仅当 Majorana≥1 且 CF=0 (trivial)**。

机制: Step3 extension loop 按 pj=3(CF), 4(Bos) 顺序尝试映射 Majorana class:
- CF 非 trivial → 映射到 CF 层成功 → `break` → 不尝试 Bosonic → 不崩溃
- CF trivial → 跳过 CF → 映射到 Bosonic 层 (p=4) → `spectrum[1]="U1"` → 经过 Bockstein → 产生 ModRat → 崩溃

### 2.6 SG#22 vs SG#42 的数学关系

两个空间群共享 **F-centered 正交 Bravais lattice**:
- SG#22 = **F222** (点群 D₂ = 222, 三个正交二重旋转轴)
- SG#42 = **Fmm2** (点群 C₂ᵥ = mm2, 一个二重轴 + 两个镜面)

**D₂ ≅ C₂ᵥ ≅ V₄ ≅ C₂×C₂** (Klein 四元群)，作为抽象群同构，只是几何实现不同
(纯旋转 vs 含反射)。两者互为 mmm (D₂ₕ) 的不同极大子群。

因为平移子群相同 + 点群抽象同构:
- Resolution 维度完全一致 (1,5,12,20,28,36,44)
- 谱序列结构高度相似: 均有 Majorana=Z₂, CF=trivial, p+ip=trivial
- 唯一差异在 Bosonic 层: SG#22 的 Z₂⁸ vs SG#42 的 Z₂²
- **两者的 bug root cause 完全相同** (相同错误信息、相同调用链、相同触发条件)

### 2.7 可能的修复方向

根据 §2.5 的分析，bug 路径为:
```
Majorana ext → 跳过 trivial CF → MapFromBarCocycle(p=4, spectrum[1]="U1")
  → SptSetBockstein (bockstein.gi:13, 归一化被注释) → 返回非整数
  → v * P 产生 ModRat → vp[i] mod R[i][i] 崩溃
```

1. **根因: `SptSetBockstein` 归一化** (bockstein.gi:13):
   `#vx := vx - Int(vx)` 被注释掉。U(1) cocycle 的值可能为负分数 (如 -7/8)，
   不归一化到 [0,1) 导致 Bockstein 返回非整数。
   但需要谨慎: notes.md 说此行被注释是有原因的 (可能影响其他计算)。

2. **防御层: `SptSetFpZModuleCanonicalElm`** (module.gi:191):
   即使上游有 bug，`vp[i] mod R[i][i]` 也应该能处理非整数输入。

3. **防御层: `SptSetSpecSeqModuleClassToLeadingVector`** (ss_module.gi:134):
   `v := SptSetMapFromBarCocycle(...)` 的返回值应该在传给 `CanonicalElm` 之前验证。

### 2.8 涉及文件 (完整)

| 文件 | 行号 | 函数 | 角色 | 可 reload |
|------|------|------|------|-----------|
| `lib/module.gi` | 176-195 | `SptSetFpZModuleCanonicalElm` | **崩溃点** | ✅ |
| `lib/bockstein.gi` | 1-18 | `SptSetBockstein` | **可能根因** | ✅ |
| `lib/ss_module.gi` | 120-138 | `ClassToLeadingVector` | 调用者 | ✅ |
| `lib/ss_module.gi` | 485-520 | `Result` Step3 loop | 触发 | ✅ |
| `lib/coefficient.gi` | 49-76 | `SptSetCoefficientCM` | 也调用 CanonicalElm | ✅ |
| `lib/bar_resolution_map_common.gi` | 98-106 | `MapFromBarCocycle` U1 | 链接 Bockstein | ❌ (含@) |
| `lib/ss_class.gi` | 51-174 | `PurifySpecSeqClass` | assertion check | ❌ (含@) |

---

## 3. Debug 环境架构

### 3.1 隔离原则

```
生产 (不动)                              Debug (随便改)
─────────────────────────────────        ────────────────────────
~/software/gap-4.13.1/pkg/SptSet/        ~/gap-debug/pkg/SptSet/
  ├── lib/module.gi (原版)                 ├── lib/module.gi (修改版)
  ├── lib/ss_module.gi (原版)              ├── lib/ss_module.gi
  └── ...                                 └── ...

PBS jobs (计算节点)                       GAP -l (cluster3)
↓ 使用生产目录                             ↓ 使用 debug 目录
monitor.sh 自动管理                       手动交互式运行
```

**关键**: 两个目录完全独立，互不干扰。
- 生产目录 = `~/software/gap-4.13.1/pkg/SptSet/` — PBS job 和 monitor.sh 使用
- Debug 目录 = `~/gap-debug/pkg/SptSet/` — 仅在 cluster3 手动调试用

### 3.2 GAP `-l` 参数原理

GAP 的 `-l` (--roots) 参数指定包搜索路径（分号分隔），排在前面的优先加载：

```bash
GAP=~/software/gap-4.13.1/gap
$GAP -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" -q -r
```

- GAP 先在 `~/gap-debug/pkg/` 中找 SptSet → 找到 → 加载 debug 版本
- GAP 在 `~/software/gap-4.13.1/pkg/` 中找其他包 (HAP 等) → 正常加载
- 生产目录的 SptSet 被 debug 版本覆盖，但文件本身完全不变

### 3.3 对生产流程的影响: **零**

| 组件 | 是否受影响 | 原因 |
|------|----------|------|
| PBS 运行中的 job | ❌ 不受影响 | 已加载代码在内存中，不读取磁盘 |
| PBS 重启的 job | ❌ 不受影响 | PBS 脚本硬编码生产目录路径 |
| monitor.sh | ❌ 不受影响 | 只做 SSH + qsub，不加载 GAP |
| checkpoint 文件 | ❌ 不受影响 | debug 使用独立的 checkpoint |
| 新提交的 job | ❌ 不受影响 | generate_batch.py 使用生产目录 |

---

## 4. 搭建步骤

### 4.1 创建 debug 副本

```bash
mkdir -p ~/gap-debug/pkg
cp -r ~/software/gap-4.13.1/pkg/SptSet ~/gap-debug/pkg/SptSet
```

### 4.2 验证 debug 版本加载正确

```bash
GAP=~/software/gap-4.13.1/gap

# 验证 debug SptSet 被优先加载
echo '
LoadPackage("sptset");
Print("SptSet loaded from: ", GAPInfo.PackagesLoaded.sptset[1], "\n");
QUIT;
' | $GAP -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" -q -r -b
```

输出应包含 `/home/user/xyren/gap-debug/pkg/SptSet`（而非生产路径）。

### 4.3 创建快速测试脚本

在 debug 目录创建测试脚本 `~/gap-debug/test_sg22.g`:

```gap
# test_sg22.g — 快速复现 SG#22 ModRat bug
#
# 用法:
#   GAP=~/software/gap-4.13.1/gap
#   cd ~/software/gap-4.13.1/pkg/SptSet/examples
#   $GAP -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" -q -r -b ~/gap-debug/test_sg22.g

LoadPackage("sptset");;
Print("=== SptSet loaded from: ", GAPInfo.PackagesLoaded.sptset[1], " ===\n");;

# 构建 SG#22 的 spectral sequence (小群，~5s)
Read("res_space_group.g");;
R := Resolution3DSpaceGroup(22, 7);;
Print("Resolution dims: ", List([0..6], i -> R!.dimension(i)), "\n");;

ss := SptSetSpecSeqVanilla(R);;
ss!.spectrum := ["U1", "Z", "Z", "Z2"];;

# Phase A: 分类 (小群，~1h on cluster3)
# 如果不想等 Phase A，直接用生产的 checkpoint:
#   $GAP -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" -q -r -L ~/checkpoints/sg22.ws -b ~/gap-debug/test_sg22_resume.g

Print("Computing classification...\n");;
for layer in [[1,3],[2,2],[3,1],[4,0]] do
    SptSetSpecSeqComponent(ss, layer[1]+layer[2], layer[1], layer[2], 5);;
od;;
Print("Phase A done.\n");;

# Phase B: 触发 bug
Print("Computing group structure (will trigger ModRat bug)...\n");;
M := SptSetSpecSeqResult(ss, 4, [1,2,3,4]);;
Print("If you see this, the bug is FIXED!\n");;
Print("Group structure: ");;
Display(M);;
```

### 4.4 利用 checkpoint 快速复现 (推荐)

SG#22 的 checkpoint (`~/checkpoints/sg22.ws`) 已包含完整的 Phase A 结果。
从 checkpoint 恢复可以**跳过 Phase A，直接触发 bug**（秒级）。

创建 `~/gap-debug/test_sg22_resume.g`:

```gap
# test_sg22_resume.g — 从 checkpoint 恢复，跳过 Phase A
#
# 重要: LoadWorkspace 恢复的是保存时的代码，需要在恢复后重新加载 debug 版本
#
# 用法 (必须用 -L 参数):
#   GAP=~/software/gap-4.13.1/gap
#   cd ~/software/gap-4.13.1/pkg/SptSet/examples
#   $GAP -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" -q -r \
#     -L ~/checkpoints/sg22.ws -b ~/gap-debug/test_sg22_resume.g

# 此时 CKPT_SS 等变量已从 checkpoint 恢复
Print("=== Resumed from checkpoint ===\n");;
Print("  CKPT_STEP = ", CKPT_STEP, "\n");;

# 重新加载 debug 版本的代码 (覆盖 checkpoint 中的旧函数)
Read("/home/user/xyren/gap-debug/pkg/SptSet/lib/module.gi");;
Read("/home/user/xyren/gap-debug/pkg/SptSet/lib/ss_module.gi");;
Print("=== Debug code reloaded ===\n");;

# 触发 Phase B (直接到 bug 点)
Print("Computing group structure...\n");;
M := SptSetSpecSeqResult(CKPT_SS, 4, [1,2,3,4]);;
Print("=== BUG FIXED! ===\n");;
SptSetFpZModuleCanonicalForm(M);;
Print("Group structure: ");;
Display(M);;
```

**注意**: `Read()` 会重新执行 `InstallGlobalFunction`，对于已安装的函数可能会
报 warning 或 error。如果遇到这种情况，需要先解绑：

```gap
# 如果 Read 报 "already installed" 错误，在 Read 之前加:
MakeReadWriteGlobal("SptSetFpZModuleCanonicalElm");
Unbind(SptSetFpZModuleCanonicalElm);
# 然后再 Read
```

---

## 5. Debug 迭代工作流

### 5.1 标准迭代周期

```
    ┌────────────────────────────────────────────┐
    │  1. 编辑 ~/gap-debug/pkg/SptSet/lib/...    │  ← IDE 中修改代码
    │  2. 运行 test script                        │  ← 终端执行 GAP
    │  3. 查看输出，分析结果                       │  ← 成功/失败？
    │  4. 如果失败，回到 1                         │
    └────────────────────────────────────────────┘
```

### 5.2 快速迭代命令

```bash
# 进入工作目录
cd ~/software/gap-4.13.1/pkg/SptSet/examples

# 方式 A: 从头跑 (慢，~1h，但不依赖 checkpoint)
~/software/gap-4.13.1/gap \
  -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" \
  -q -r -b ~/gap-debug/test_sg22.g

# 方式 B: 从 checkpoint 恢复 (快，秒级，推荐)
~/software/gap-4.13.1/gap \
  -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" \
  -q -r -L ~/checkpoints/sg22.ws -b ~/gap-debug/test_sg22_resume.g
```

### 5.3 交互式调试

```bash
# 启动交互式 GAP (带 debug SptSet)
cd ~/software/gap-4.13.1/pkg/SptSet/examples
~/software/gap-4.13.1/gap \
  -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" -q -r

# 然后在 GAP 中:
gap> LoadPackage("sptset");
gap> Read("res_space_group.g");
gap> # ... 手动逐步执行，插入 Print/Display 调试 ...
```

### 5.4 调试 tips

```gap
# 打印 v 向量的类型（看是不是 ModRat）
Print(List(v, x -> [x, IsRat(x), IsInt(x)]), "\n");

# 打印投影矩阵 P 的元素类型
Print(List(P, row -> List(row, x -> IsInt(x))), "\n");

# 检查 MapFromBarCocycle 返回值
v := SptSetMapFromBarCocycle(ss!.brMap, p, spec, layer);
Print("v = ", v, "\n");
Print("types = ", List(v, x -> TNAM_OBJ(x)), "\n");

# 手动测试 mod 操作
a := v[i];  # 看 a 是什么类型
Print(a, " mod ", R[i][i], "\n");
```

---

## 6. 修复合并回生产

debug 验证修复有效后，将改动同步回生产目录：

```bash
# 查看改了哪些文件
diff -rq ~/gap-debug/pkg/SptSet/lib/ ~/software/gap-4.13.1/pkg/SptSet/lib/

# 查看具体改动
diff ~/gap-debug/pkg/SptSet/lib/module.gi ~/software/gap-4.13.1/pkg/SptSet/lib/module.gi

# 确认无误后复制回去
cp ~/gap-debug/pkg/SptSet/lib/module.gi ~/software/gap-4.13.1/pkg/SptSet/lib/module.gi
```

合并后：
- **正在运行的 job 不受影响**（代码已在内存中）
- **新提交的 job 自动使用修复后的代码**
- **从 checkpoint 恢复的 job 也会加载新代码**
- monitor.sh 可以将 SG#22/42 从 errored 列表中移除，重新提交

---

## 7. cluster3 环境注意事项

| 项目 | 说明 |
|------|------|
| GAP 二进制 | `~/software/gap-4.13.1/gap`（在 cluster3 上直接可用） |
| LD_LIBRARY_PATH | cluster3 不需要设置（Ubuntu 24.04 系统库兼容） |
| CPU | Xeon E5-2603 v4 @ 1.70GHz, 12 cores（比计算节点慢 ~30%） |
| 内存 | 62GB（SG#22 等小群足够） |
| 并行 | 设 `SPTSET_PARALLEL_JOBS := 10` (留 2 核余量，cluster3 只有 12 核) |
| checkpoint | 使用独立路径 (如 `~/checkpoints/debug_sg22.ws`)，**不要覆盖生产 checkpoint** |

---

## 8. 后续: s12 模式调试

同样的环境可用于 s12 模式调试：

```gap
# 在 test script 中改 spectrum
ss!.spectrum := ["U1", "Z2", "Z", "Z2"];  # s12 模式
```

s12 模式的已知 bug (C3v/C4v assertion error) 与 ez 的 ModRat bug 不同，
但 debug 环境和工作流完全相同。

---

## 9. 文件结构总览

```
~/gap-debug/                              # debug 根目录
├── pkg/
│   └── SptSet/                           # SptSet debug 副本（从生产目录复制）
│       ├── lib/
│       │   ├── module.gi                 # ← 主要修改目标
│       │   ├── ss_module.gi              # ← 可能需要修改
│       │   └── ...
│       └── ...
├── test_sg22.g                           # 从头跑的测试脚本
└── test_sg22_resume.g                    # 从 checkpoint 恢复的测试脚本
```

---

## 10. 快速参考

```bash
# 搭建 debug 环境
mkdir -p ~/gap-debug/pkg
cp -r ~/software/gap-4.13.1/pkg/SptSet ~/gap-debug/pkg/SptSet

# 快速复现 bug（秒级）
cd ~/software/gap-4.13.1/pkg/SptSet/examples
~/software/gap-4.13.1/gap \
  -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" \
  -q -r -L ~/checkpoints/sg22.ws -b ~/gap-debug/test_sg22_resume.g

# 查看改动
diff -r ~/gap-debug/pkg/SptSet/lib/ ~/software/gap-4.13.1/pkg/SptSet/lib/

# 合并修复到生产
cp ~/gap-debug/pkg/SptSet/lib/module.gi ~/software/gap-4.13.1/pkg/SptSet/lib/

# 版本控制 (可选，通过 head 节点)
ssh head 'cd ~/gap-debug/pkg/SptSet && git init && git add -A && git commit -m "baseline"'
ssh head 'cd ~/gap-debug/pkg/SptSet && git diff'
ssh head 'cd ~/gap-debug/pkg/SptSet && git add -A && git commit -m "fix ModRat"'
```

---

## 11. 环境搭建状态 (2026-03-02)

### 11.1 已完成

| 项目 | 状态 | 详情 |
|------|------|------|
| Debug 副本 | ✅ | `~/gap-debug/pkg/SptSet/`，lib/ 与生产完全一致 |
| Git 仓库 | ✅ | 分支 `dev/cluster_debug`，baseline commit |
| GAP -l 加载 | ✅ | 确认从 debug 目录加载 SptSet |
| Checkpoint | ✅ | sg22.ws (130MB) 和 sg42.ws (131MB) |
| 测试脚本 | ✅ | `test_sg22.g`, `test_sg22_resume.g` |
| `reload.g` | ✅ | 重载 bockstein/module/coefficient/ss_module (无 @ 文件) |
| 生产隔离 | ✅ | 生产 lib/ 与 debug lib/ 零差异 |
| 端到端验证 | ✅ | checkpoint 恢复 → reload → 到达 bug 触发点 |

### 11.2 reload.g 文件清单

安全可重载 (无 `@` 文件局部变量):
- `bockstein.gi` → `SptSetBockstein`
- `module.gi` → `SptSetFpZModuleCanonicalElm`
- `coefficient.gi` → `SptSetCoefficientCM`
- `ss_module.gi` → `SptSetSpecSeqResult`

不可直接 `Read()` 重载 (含 `@`):
- `bar_resolution_map_common.gi` — 需用 `MakeReadWriteGlobal` + 直接赋值
- `ss_class.gi` — 同上

### 11.3 Debug 策略

**推荐从 SG#22 开始** (debug 迭代 ~50 min vs SG#42 ~70 min)。
Root cause 完全相同，SG#22 修复后 SG#42 应自动修复。

从 checkpoint 恢复的快速迭代:
```bash
cd ~/software/gap-4.13.1/pkg/SptSet/examples
~/software/gap-4.13.1/gap \
  -l "$HOME/gap-debug/;$HOME/software/gap-4.13.1/" \
  -q -r -L ~/checkpoints/sg22.ws -b ~/gap-debug/test_sg22_resume.g
```

---

## 12. 深入分析：Stacking/AddTwister Bug (2026-03-02)

### 12.1 Bockstein 方向已排除

之前的分析 (§2.7) 认为根因是 `SptSetBockstein` 归一化被注释掉。**这个方向是错的**。

真正的 assertion `ForAll(cp, IsInt)` 的物理含义:
- "top layer is not a cocycle" = stacking 后的 obstruction function O5 不满足 dO5=0
- 这与 C3v/C4v (s12) 是**同一个 root cause**
- 不是归一化问题，而是 **stacking 计算本身给出了错误结果**

### 12.2 公式 vs 算法 Bug

两种可能性:
1. stacking 公式 (addTwister) 本身有错 → 但应该大面积出问题
2. 算法在特定 case 下有 bug → 更可能，因为绝大多数群正确

230+ 空间群只有 SG#22/42 crash，且公式涉及精确的 cup products 和 Z/8 相位表，
"差一点就差之千里"，如果公式整体错了不可能只影响两个群。
**因此极可能是算法 bug，在特定条件下触发。**

### 12.3 关键发现: `addTwister(4,0)` 的 Masking 效应

**`SptSetStack` (ss_cochain.gi:24-44) 对 p=4 层始终计算 `addTwister(4,0)`，无条件。**

但 Bosonic 层的验证取决于 `PurifySpecSeqClass` 是否处理到 p=4:

| 场景 | MC stacking | addTwister(4,0) Majorana 项 | p=4 验证 | 结果 |
|------|------------|---------------------------|---------|------|
| CF≠0 (如 SG#40) | ✅ 计算了 | **非零** (n21,n22≠0) | ❌ 不检查 (break at p=3) | MASKED |
| CF=0 (SG#22/42) | ✅ 计算了 | **非零** (n21,n22≠0) | ✅ 检查 | ❌ CRASH |
| CF stacking | ✅ 计算了 | **零** (n21=n22=0) | ✅ 检查 | ✅ OK |

**机制:**
- `PurifySpecSeqClass` 从 p=0 向上遍历
- 在 p=3 (CF) 发现非零 class → **break** → p=4 从不检查
- CF=0 时: p=3 被 trivialize → 继续到 p=4 → assertion 触发

**推论:**
在 CF≠0 的成功案例中，addTwister(4,0) 的 Majorana 相关项
（e4cg, t4, 以及 e4c 中涉及 m3 的项）虽然被计算了，
但产生的值**从未被检验也从未被使用**。
如果这些值实际上是错的，只有在 CF=0 时才暴露。

### 12.4 V4 点群测试结果

测试了 D2 和 C2v 作为**点群** (非空间群) 在 ez 模式下:

| 点群 | nGens [MC, CF, Bos] | 结论 |
|------|--------------------|----|
| D2 (V4) | [0, 0, 2] | MC=0! 不触发 bug 路径 |
| C2v (V4) | [0, 0, 0] | 全 trivial |

**点群没有平移子群，所以 MC=0。**
"所有 ez 点群通过"并不能证明 addTwister(4,0) 的 Majorana 项是对的
——它们从来没有在点群层面被真正测试过。

空间群 SG#22 的 MC=1 来自**平移子群对 H^2(G,Z2) 的贡献**。

### 12.5 s12 版 addTwister(4,0) 对比

`ss_fermion.gi:302-349` (s12) vs `ss_fermion_ez.gi:299-343` (ez):
结构完全相同，只有 dn3 多了 `Cup0(w, n2)` 项，t4 的 ExtData 第 3 参数从 0 变为 w(g1,g2)。

C3v/C4v (s12) 也出同样的问题，说明 bug 不是 ez 特有的。

S4 (s12) CF=0 但正确给出 Z_2×Z_2 — 需要确认 S4 是否真的走了 MC→Bosonic 路径，
以及 S4 的 Majorana cochains 是否碰巧避开了 buggy 分支。

### 12.6 当前诊断实验

在 ss_module.gi 的 `ClassToLeadingVector` 添加了诊断输出:
- Purify 前: 打印每层的 MapFromBarCocycle 结果和 IsInt 状态
- Purify 后: 打印 leading layer

从 SG#22 checkpoint 运行中 (预计 ~50 min)。

### 12.7 SG#22 诊断确认

SG#22 诊断输出 (从 checkpoint 恢复后):
```
nGens = [0, 1, 0, 8]
p=1: nonzero, allInt=true
p=2: nonzero, allInt=true
p=3: nonzero, allInt=true
p=4: nonzero, allInt=false, vec[1..8] 包含 .../2 分数
ASSERTION FAILURE: top layer is not a cocycle
```

**关键确认**: p=4 (Bosonic) 层在 `PurifySpecSeqClass` 之前就已经是 non-integer。
bug 确认在 `SptSetStack`/`addTwister(4,0)` 中产生。

### 12.8 C4v 为什么 assertion 不崩溃

GAP 的 `Assert(-1, condition, message)` **三参数形式**: condition 为 false 时
**只打印 message，不抛出 Error**。

- C4v: assertion 打印 WARNING，程序继续，rational 值碰巧不触发后续 `mod` crash → 结果 Z₂⁴ 正确
- SG#22/42: assertion 打印 WARNING，后续 `vp[i] mod R[i][i]` 触发 `ModRat coprime error` → CRASH
- C3v: assertion 打印 WARNING，rational 传播到 SNF → FATAL ERROR

三者**同一个 root cause**，只是 rational 在后续计算中的命运不同。

---

## 13. Extension 架构重构 (2026-03-03)

### 13.1 三种 Extension 策略对比

| | 旧代码 (ResultOld) | 上一版新代码 (ResultLayerwise) | 当前 Hybrid 方案 |
|---|---|---|---|
| p+ip 处理 | 混入 MC 做 sequential | 独立，只看 MC | 独立，只看 MC |
| MC→CF | sequential (Z-lift 可能被 p+ip 抵消) | layer-by-layer (独立) | sequential (干净 MC gen) |
| MC→Bos | sequential (正确捕获 c 系数) | **丢失** (break) | sequential (正确捕获 c 系数) |
| CF→Bos | sequential | layer-by-layer (独立) | sequential (正确) |

### 13.2 为什么 p+ip 必须单独处理

`ss_fermion.gi:286-288` / `ss_fermion_ez.gi:283-285`:
```gap
SptSetInstallAddTwister(ss, 1, 3, {l1, l2} -> ZeroCocycle@);  # p+ip → Bos: 物理未知
SptSetInstallAddTwister(ss, 2, 2, {l1, l2} -> ZeroCocycle@);  # MC at deg4: 物理未知
```

`addTwister(1,3) = 0` 和 `addTwister(2,2) = 0` 是 placeholder，物理上未知 (d3/d4)。
因此 p+ip 对 CF/Bos 的贡献通过 stacking 公式计算**不可信**。
p+ip 只能可靠地 extend 到 MC 层。

而 `addTwister(3,1)` 和 `addTwister(4,0)` 是**完全已知的物理公式**，
MC→CF→Bos 的 sequential extension 能正确捕获所有跨层系数。

### 13.3 旧代码 (ResultOld) 的 S4 bug

来源: `Latex_note.tex` 第 2080-2087 行

```
M12 = Extension(p+ip, MC) 产生混合生成元 g = -pip + MC
g 的 MC 层 = -(-1) + (-1) = 0  ← Z-lift 相消!
于是 4*g 没有 MC 贡献 → addTwister(3,1) 给零 → CF 投影为零
实际上 4*g 应该投影到 CF (Z_16 extension)
```

问题是 p+ip 和 MC 的 Z-lift 在整数上相消，导致混合生成元丢失 MC 信息。

### 13.4 上一版新代码 (ResultLayerwise) 的 c 系数丢失

Layer-by-layer 方法对 MC gen 只取 leading layer (CF) 就 break，丢失 Bos 的 c 系数:

完整矩阵: `| t1  a  c |`   vs   新代码: `| t1  a  0 |`
           `| 0  t2  b |`                  `| 0  t2  b |`
           `| 0   0 t3 |`                  `| 0   0 t3 |`

反例: t1=2, t2=2, t3=4, a=1, c=1, b=2
- 完整矩阵 SNF → Z₄ × Z₄
- 丢失 c 后 SNF → Z₈

两种方法给出**不同的群**！

### 13.5 Hybrid 方案

**设计**: `SptSetSpecSeqResult(ss, deg, pRange)` 
1. 如果 pRange 包含 p+ip (p=1):
   - p+ip: 独立计算，只 extend 到 MC
   - MC+CF+Bos: sequential extension (旧方法)，正确捕获所有跨层系数
   - 用 `SptSetSpecSeqModuleExtension(Epip, M_rest)` 合并
2. 如果 pRange 不含 p+ip:
   - 直接用 sequential extension

**代码改动**:
- `ss_module.gi`: `SptSetSpecSeqResult` 重写为 Hybrid
- `SptSetSpecSeqModuleExtension`: 放宽 assert，支持多层 M2
  (原来 assert `Length(M2!.pRange) = 1`，现在允许多层)
- 原 layer-by-layer 代码保留为 `SptSetSpecSeqResultLayerwise`

**Benchmark**: test_hybrid.g, 测试 S4/C4v/C3v/Cs/C2h (s12)
