# 实验铁律（每次跑实验前必读）

## 1. 生产线与 debug 线严格隔离

- **生产线**：`/home/user/xyren/software/gap-4.13.1/pkg/SptSet/`
- **Debug 线**：`/home/user/xyren/gap-debug/pkg/SptSet/`

**绝对禁止**：修改、写入、加载生产线的任何文件。所有改动只能在 debug 线。

启动 GAP 时必须用 `-l` 参数优先加载 debug 线：
```
gap -l "/home/user/xyren/gap-debug/;/home/user/xyren/software/gap-4.13.1/" -r -q -b script.g
```

每个实验脚本开头必须加验证：
```gap
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
if PositionSublist(_sptset_path, "gap-debug") = fail then
    Print("FATAL: SptSet loaded from ", _sptset_path, " — NOT debug version!\n");;
    FORCE_QUIT_GAP(1);;
fi;;
Print("OK: SptSet loaded from ", _sptset_path, "\n");;
```

## 2. 必须走源代码，禁止自己瞎写

实验脚本只负责：设置群、调用 `FermionEZSPTSpecSeq` / `FermionSPTSpecSeq`、调用 `FermionSPTLayersVerbose` / `FermionEZSPTLayersVerbose`、调用 `SptSetSpecSeqResult`。

**禁止**在实验脚本中重写或绕过 `lib/` 下的核心函数逻辑。所有计算必须经过 debug 线 `lib/` 的源代码路径。如需修改计算逻辑，改 `lib/` 源文件，不要在实验脚本里 hack。

## 3. 全面 trouble shooting

在以下每个关键点加入整数性检查，捕获最早出现的分数错误：

- `SptSetBockstein` 输出后：结果必须全部是整数
- `SptSetFpZModuleCanonicalForm` 输入 `M!.relations`：矩阵元素必须全部是整数
- `SptSetZLMapInverse` 输出后：结果必须全部是整数
- Phase B 的 `SptSetPurifySpecSeqClass` 中间步骤

检查方式：在 `lib/` 源码的对应位置加 `if not ForAll(..., IsInt) then Print(...); fi;`，打印具体位置、具体值、第几个分量出错。**只打印不中断**，让程序继续运行以收集完整信息。

目标：定位从 MC 层到 Bosonic 层的计算链路中，**最早**出现非整数值的那一步。

## 4. 必须用并行计算

```gap
SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_PHASE2 := true;;
```

详见 `notes/parallel_computing.md`。在 cluster3 上跑，尽量多用 core。

## 5. 不加载 checkpoint，从头开始

```gap
CKPT_MODE := false;;
```

或者直接不设 checkpoint 相关变量。每次实验必须从头算，确保结果基于当前代码，不受旧 workspace 影响。
