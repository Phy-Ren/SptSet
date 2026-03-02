# SptSet Debug 环境：集群调试方案

**日期: 2026-03-02**
**状态: 方案就绪，待执行**

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

| SG # | Resolution dims | E^{2,2}_inf | Phase A | Phase B |
|------|----------------|-------------|---------|---------|
| 22 | 1,5,12,20,28,36,44 | [2] | ✅ 完成 | ❌ Step3 崩溃 |
| 42 | 1,5,12,20,28,36,44 | [2] | ✅ 完成 | ❌ Step3 崩溃 |

确定性 bug — SG#22 已重试 5 次，每次完全相同的错误。

### 2.5 可能的修复方向

1. **在 `SptSetFpZModuleCanonicalElm` 中处理 ModRat**:
   `vp[i]` 可能是 `r/s mod n` 形式的 ModRat，做 `mod R[i][i]` 时需要先转为整数。
   调查 `v * P` 为何产生 ModRat（`v` 来自 `SptSetMapFromBarCocycle`，`P` 是投影矩阵）。

2. **在 `SptSetSpecSeqModuleClassToLeadingVector` 中清理输入**:
   在调用 `SptSetFpZModuleCanonicalElm` 之前，确保向量 `v` 是纯整数。

3. **检查 `SptSetMapFromBarCocycle` 的返回值**:
   确认返回的 cocycle 向量应该是整数还是可以是有理数。

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
