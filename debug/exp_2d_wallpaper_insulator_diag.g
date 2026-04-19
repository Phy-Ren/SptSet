# 2D wallpaper groups (#2-#17) insulator EZ Phase A + Phase B 诊断 — 遵守实验铁律
# 从头开始，不加载 checkpoint，走 insulator 线 lib/ 源代码
# 模板：debug/exp_sg42_ez_diag.g
#
# ============================================================
# 背景
# ------------------------------------------------------------
# 2026-04-19 Xingyu 在 lib/ss_ti.gi 新增三条 3+1D 公式：
#     d_3^{0,3}      = beta(omega_2) cup_0 n_0
#     d_2^{3,1}      = omega_2 cup_0 n_3 + 1/2 n_3 cup_1 n_3
#     T_{4,0}        = 1/2 n_3 cup_2 n_3
# 这三条公式只在 3+1D（总度 = 4）才会被实际激活；2+1D（总度 = 3）下：
#     - d_3^{0,3} 的源在 (p=0, q=3)，目标 (p=3, q=1)，可影响 CF 层
#       但本脚本所有 wallpaper 群都用 omega_ = 0 → beta(omega_) = 0 → 该项归零
#     - d_2^{3,1} 跳到 (p=5, q=0)，超出 2D 总度 3，根本进不到
#     - T_{4,0} 是 p=4 处 twister，超出 2D 总度，进不到
# 因此本脚本是新公式的 **2D 回归测试**：Phase A 输出必须与
# examples/fspt_2d_insulator-result.txt 完全一致（已在 [2] 验证 16/16 PERFECT MATCH）。
#
# Phase B 部分是 **insulator 路径上 SptSetSpecSeqResult 的首次实战测试**：
# 历史上 examples/fspt_2d_insulator.g 走的是手动 stacking + anomaly 提取，
# 而 examples/fspt_2d_ez_ext.g (superconductor 版) 走的是标准 SptSetSpecSeqResult。
# 本脚本验证：标准 Phase B 路径对 InsulatorSPTSpecSeq 是否能用。
#
# ============================================================
# 实验设计
# ------------------------------------------------------------
#   * 16 个 wallpaper 群 (SG#2..#17)，逐一构建 InsulatorSPTSpecSeq
#   * omega_ = 0 (EZ formula, spinless insulator)
#   * auMap = u1cMap = DeterminantMat（反演/镜面 → -1，平移 → +1）
#   * Phase A: InsulatorSPTLayersVerbose(SS, 2) 输出每层各页
#   * Phase B: SptSetSpecSeqResult(SS, 3, [1,2,3]) + SptSetFpZModuleCanonicalForm + Display
#              参数与 examples/fspt_2d_ez_ext.g 一致（2D 总度 = 3，三层）
#   * Phase A 和 Phase B **分别独立 CALL_WITH_CATCH** —— Phase B 崩不会污染 Phase A 结果
#   * Phase A 崩则跳过 Phase B（无 SS 可用）
#
# ============================================================
# 运行方式
# ------------------------------------------------------------
#     ~/software/gap-4.13.1/gap \
#         -l "/home/user/xyren/gap-insulator/;/home/user/xyren/software/gap-4.13.1/" \
#         -r -b debug/exp_2d_wallpaper_insulator_diag.g \
#         > debug/exp_2d_wallpaper_insulator_diag.log 2>&1
#
# 也可设置环境变量 SG_RANGE 控制范围（默认 [2..17]，可改 "[2,3]" 等小范围）。
#
# ============================================================
# Trouble shooting / 历次运行记录
# ------------------------------------------------------------
#
# [1] 2026-04-19 首次运行：LoadPackage 报 ext_data.gi 错
# ----------------------------------------------------------------
#     Error, no method found! For debugging hints type ?Recovery from NoMethodFound
#     Error, no 1st choice method found for `InputTextFile' on 1 arguments
#       at .../lib/ext_data.gi:11
#
#     根因: 当前 worktree 的 lib/data/ 目录被 .gitignore 忽略了
#           AddTwister2D.dat / AddTwister3D.dat / O5gamma.dat 三个文件，
#           git worktree 切出来时这三个文件不会跟过来。
#     修复: 从 debug 线复制（已写入 notes/CursorRead.md §6）：
#           cp ~/gap-debug/pkg/SptSet/lib/data/{AddTwister2D,AddTwister3D,O5gamma}.dat \
#              ~/gap-insulator/pkg/SptSet/lib/data/
#
# [2] 2026-04-19 第二次运行：成功
# ----------------------------------------------------------------
#     总耗时: 53.6 秒 (16 个 wallpaper 群, 不含 LoadPackage ~13s)
#     全部 16 群 OK, 0 CRASH
#     并行统计: P1 9 parallel calls (2668ms) + 2 sequential (319ms)
#                P2 13 calls (15508ms), max_m=4
#
#     关键回归验证：与 examples/fspt_2d_insulator-result.txt 比对
#                Empty/Complex fermion/Bosonic 三层 → 16/16 PERFECT MATCH
#     结论: 新加的 d_3^{0,3}, d_2^{3,1}, T_{4,0} 三条公式
#           不破坏 2D 现有结果（符合理论预期，详见脚本头部 "背景"）。
#
# [3] 已知 LoadPackage warning（可忽略）
# ----------------------------------------------------------------
#     #E component `License'/`ArchiveURL'/... must be bound ...
#     #E Validation of package sptset ... failed
#     这是 PackageInfo.g 缺 GAP 4.10+ 必填字段，不影响功能（详见 CursorRead.md §7）。
#
# [4] 2026-04-19 Phase B 改造：加 SptSetSpecSeqResult
# ----------------------------------------------------------------
#     说明: examples/fspt_2d_insulator.g 走的是 FermionSPTLayers + 手动 stacking +
#           手动 anomaly 提取，**不**调 SptSetSpecSeqResult，所以
#           examples/fspt_2d_insulator-result.txt 里没有 group structure 可以
#           直接对照。本脚本 Phase B 输出 = insulator 路径下 SptSetSpecSeqResult
#           的**新基线**。
#
# [5] 2026-04-19 Phase B 在 SG#2 的 Dim(7) crash 与修复
# ----------------------------------------------------------------
#     现象: depth=6 + Phase B 在 SG#2 第一群 ComponentEx(2,1) class 1/4 时即崩
#         Error, List Element: <list>[7] must have an assigned value
#         in return Length(PseudoBoundary[i])
#         at .../hap/lib/Resolutions/resFiniteGroup.gi:180
#         called from DimensionR(j) at .../twistedTensorProduct.gi:131
#         called from Dimension(resolution)(k) at lib/cochain.gi:22
#         called from SptSetCochainModule(R, deg+1=7, 0) at lib/cochain.gi:36
#         called from SptSetCochainModule(R, p=6, U(1)) at lib/ss_vanilla.gi:75
#         called from SptSetSpecSeqBuildComponent(ss, r=1, p=6, q=0)
#
#     根因 call chain (新加的 d_3^{0,3} + d_2^{3,1} 联合触发):
#         ComponentEx(2,1) → ClassFromLevelCocycle(deg=3, p=2)
#           → PurifySpecSeqClass: p=4 layer (q=0, U(1))
#           → ComponentInf(4,0) = Component(5, 4, 0)
#           → BuildComponent(5,4,0): φ=Deriv(4,0,3)
#           → Deriv(4,0,3): N=Component(4,4,0), M=Component(4,0,3)
#           → BuildComponent(4,0,3): ψ=Deriv(3,0,3)  【新加 d_3^{0,3}】
#           → BuildDeriv(3,0,3): N=Component(3,3,1)
#           → BuildComponent(3,3,1): ψ=Deriv(2,3,1)  【新加 d_2^{3,1}】
#           → BuildDeriv(2,3,1): N=Component(2,5,0)
#           → BuildComponent(2,5,0): ψ=Deriv(1,5,0)
#           → CoboundaryMap on C^5(G,U(1)) → C^6(G,U(1))
#           → CochainModule(R, 6+1=7, 0) → Dim(7) → PseudoBoundary[7] ❌
#
#     原因解释:
#         U(1) 系数的 cochain at p 通过 Z 系数 at p+1 实现 (lib/cochain.gi:36)
#         所以 C^p(G, U(1)) 需要 PseudoBoundary[p+1]; cobdry 还需要 [p+2]。
#         d_2^{3,1} 把 (3,1)→(5,0)，目标 C^5(G,U(1)) cobdry 进 C^6(G,U(1)) 需要 Dim(7)。
#         d_3^{0,3} 经 Component(3,3,1) → Deriv(2,3,1) 拉出 d_2^{3,1} 这条路径。
#         超导 (FermionEZ) 同样有 d_2^{3,1}，但 d_3^{0,3} 是占位 return 0；
#         可能因 spectrum[3]=Z_2 vs 绝缘体 spectrum[3] 未绑定，部分子组件早退出。
#         （TODO: 详细对比超导路径，确认到底是哪个早退出救了它。）
#
#     修复: 把 ResolutionAlmostCrystalGroup(SG1, 6) → 7
#         resolution 多算一层 (PseudoBoundary[7] 也填上)
#         代价: resolution 构建时间增加 ~2-3x，但 Phase B 才能跑
#
#     另: CALL_WITH_CATCH 在这种 List index out-of-bounds 错误下没拦截住，
#         脚本进了 brk> 循环导致提前终止。补救：加 BreakOnError := false。
#
# [6] 2026-04-19 depth=7 + Phase B 全部 16 群通过
# ----------------------------------------------------------------
#     总耗时: 930.135 秒 (~15.5 分钟, depth 6→7 主要拖慢复杂群)
#     Phase A: 16/16 OK, 仍然 PERFECT MATCH 与 examples/fspt_2d_insulator-result.txt
#     Phase B: 16/16 OK
#     并行统计:
#         P1: 79 parallel (105.7s) + 66 sequential (10.3s)
#         P2: 26 calls (756.9s), max_m=8
#         P2b: 0 calls (Phase B 内部 ext 都用 sequential 模式)
#
#     Phase B 群结构 (insulator, dim=2 → SPT 总度=3):
#         SG#2 : [ 2, 4, 4, 4, 0 ]
#         SG#3 : [ 2, 4, 0 ]
#         SG#4 : [ 0 ]
#         SG#5 : [ 2, 0 ]
#         SG#6 : [ 2, 2, 2, 2, 2, 2, 2, 2, 0 ]
#         SG#7 : [ 2, 4, 4, 0 ]
#         SG#8 : [ 2, 4, 0 ]
#         SG#9 : [ 2, 2, 2, 2, 4, 0 ]
#         SG#10: [ 2, 4, 4, 8, 0 ]
#         SG#11: [ 2, 2, 2, 2, 2, 2, 2, 0 ]
#         SG#12: [ 2, 2, 2, 4, 0 ]
#         SG#13: [ 3, 3, 3, 3, 3, 0 ]
#         SG#14: [ 3, 6, 0 ]
#         SG#15: [ 3, 6, 0 ]
#         SG#16: [ 3, 6, 12, 0 ]
#         SG#17: [ 2, 2, 2, 6, 0 ]
#     注: 每个群末尾的 "0" 是 Z 因子，对应 CF 层的 charge pumping invariant
#         (绝缘体 spectrum[2]=Z, 不同于超导 spectrum[2]=Z_2)
#         这是绝缘体物理上的关键不变量（U(1) charge transfer per cycle）
#     与超导 (examples/fspt_2d_ez_ext-result.txt) 对比，超导对应群结构无 Z 因子
#         例 SG#2: 绝缘体 [ 2, 4, 4, 4, 0 ] vs 超导 [ 4, 8, 8, 8 ]
#         例 SG#6: 绝缘体 [ 2, 2, 2, 2, 2, 2, 2, 2, 0 ] vs 超导 [ 2, 2, 2, 2, 2, 2, 2, 2 ]
#


LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

# 防止 Phase B 出错时进 brk> 循环；批模式下 List/PseudoBoundary 越界等错误
# 不会被 CALL_WITH_CATCH 完全拦截，必须配合 BreakOnError 使用
BreakOnError := false;;

# ============ 铁律 1: 验证加载的是 insulator 线 ============
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Print("================================================================\n");;
Print("2D wallpaper groups insulator EZ Phase A + Phase B diagnostic\n");;
Print("  SptSet loaded from: ", _sptset_path, "\n");;
if PositionSublist(_sptset_path, "gap-insulator") = fail then
    Print("  FATAL: NOT loading insulator version! Aborting.\n");;
    FORCE_QUIT_GAP(1);;
fi;;
Print("  OK: insulator version confirmed.\n");;

# ============ 铁律 4: 并行计算 ============
SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;
Print("  Parallel: JOBS=", SPTSET_PARALLEL_JOBS,
      " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
      " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");;

# ============ 铁律 5: 不加载 checkpoint ============
Print("  Checkpoint: disabled (CKPT_MODE not set)\n");;

# ============ 铁律 3: 诊断已加入 lib/ 源码 (12 checkpoints, 继承 debug 线) ============
Print("  Diagnostics (12 points in lib/ source code, from debug line):\n");;
Print("    Bockstein, ZLMapInverse, CanonicalForm, PurifyClass,\n");;
Print("    PartialPurify-stack, PurifyCobdry-stack, PartialPurifySSClass,\n");;
Print("    PartialConstruct, BuildDeriv-par, BuildDeriv-seq,\n");;
Print("    ClassToLeadVec, ModExt-vjnf\n");;

# ============ 实验范围 ============
SG_RANGE := [2..17];;
Print("  Wallpaper group range: SG#", SG_RANGE[1],
      "..#", SG_RANGE[Length(SG_RANGE)],
      " (", Length(SG_RANGE), " groups)\n");;
Print("================================================================\n\n");;

# ============ 主循环 ============
omega0 := {g1, g2} -> 0;;
_results := [];;
_t_total := NanosecondsSinceEpoch();;

for it in SG_RANGE do
    Print("\n################################################################\n");;
    Print("# SG#", it, " (wallpaper group)\n");;
    Print("################################################################\n");;
    _t_grp := NanosecondsSinceEpoch();;

    SS := fail;;
    Unbind(M);;

    _phaseA_ok := CALL_WITH_CATCH(function()

        SG := SpaceGroupBBNWZ(2, it);;
        fSG := IsomorphismPcpGroup(SG);;
        SG1 := Image(fSG);;

        Print("Building resolution (depth=7, Phase B 需要 PseudoBoundary[7])...\n");;
        _t := NanosecondsSinceEpoch();;
        R := ResolutionAlmostCrystalGroup(SG1, 7);;
        Print("  Resolution built in ",
              Int((NanosecondsSinceEpoch()-_t)/1000000), " ms\n");;
        Print("  Dimensions: ");;
        for _d in [0..7] do Print(R!.dimension(_d), " "); od;;
        Print("\n");;

        gs := GeneratorsOfGroup(SG);;
        f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
            List(gs, x -> Image(fSG, x)),
            List(gs, x -> [[DeterminantMat(x)]]));;

        Print("Building spectral sequence (InsulatorSPTSpecSeq, EZ, omega=0)...\n");;
        _t := NanosecondsSinceEpoch();;
        SS := InsulatorSPTSpecSeq(R, f, f, omega0);;
        Print("  Spectral sequence created in ",
              Int((NanosecondsSinceEpoch()-_t)/1000000), " ms\n\n");;

        Print("Phase A: InsulatorSPTLayersVerbose(SS, 2)\n");;
        Print("------------------------------------------------------------\n");;
        _t := NanosecondsSinceEpoch();;
        InsulatorSPTLayersVerbose(SS, 2);;
        Print("------------------------------------------------------------\n");;
        Print("Phase A completed in ",
              Int((NanosecondsSinceEpoch()-_t)/1000000), " ms\n");;
    end, []);;

    _dtA := Int((NanosecondsSinceEpoch()-_t_grp)/1000000);;

    if _phaseA_ok[1] then
        Print("\n*** Phase A OK in ", _dtA, " ms ***\n");;

        # ---- Phase B (only if Phase A succeeded) ----
        Print("\nPhase B: SptSetSpecSeqResult(SS, 3, [1,2,3]) — insulator path 首次实战\n");;
        Print("------------------------------------------------------------\n");;
        _tB := NanosecondsSinceEpoch();;
        _phaseB_ok := CALL_WITH_CATCH(function()
            M := SptSetSpecSeqResult(SS, 3, [1,2,3]);;
            SptSetFpZModuleCanonicalForm(M);;
        end, []);;
        _dtB := Int((NanosecondsSinceEpoch()-_tB)/1000000);;

        if _phaseB_ok[1] then
            Print("------------------------------------------------------------\n");;
            Print("Phase B OK in ", _dtB, " ms\n");;
            Print("Group structure: ");;
            Display(M);;
        else
            Print("\n!!! Phase B CRASHED after ", _dtB, " ms !!!\n");;
            Print("    Error: ", _phaseB_ok[2], "\n");;
        fi;;
    else
        Print("\n!!! Phase A CRASHED after ", _dtA, " ms !!!\n");;
        Print("    Error: ", _phaseA_ok[2], "\n");;
        Print("    Phase B SKIPPED (no SS available)\n");;
        _phaseB_ok := [false, "skipped (Phase A failed)"];;
        _dtB := 0;;
    fi;;

    _dt_grp := Int((NanosecondsSinceEpoch()-_t_grp)/1000000);;
    Print("\n*** SG#", it, " total: ", _dt_grp,
          " ms (PhaseA=", _dtA, " ms, PhaseB=", _dtB, " ms) ***\n");;

    _rec := rec(
        it := it,
        phaseA_ok := _phaseA_ok[1],
        phaseB_ok := _phaseB_ok[1],
        dt_total := _dt_grp,
        dt_A := _dtA,
        dt_B := _dtB);;
    if not _phaseA_ok[1] then _rec.phaseA_err := _phaseA_ok[2];; fi;;
    if not _phaseB_ok[1] then _rec.phaseB_err := _phaseB_ok[2];; fi;;
    Add(_results, _rec);;
od;;

_dt_total := Int((NanosecondsSinceEpoch()-_t_total)/1000000);;

# ============ Final Summary ============
_OkStr := function(b) if b then return "  OK "; else return "CRASH"; fi; end;;

Print("\n\n================================================================\n");;
Print("FINAL SUMMARY\n");;
Print("================================================================\n");;
Print("Total wall time: ", _dt_total, " ms (",
      Float(_dt_total/1000.0), " s)\n\n");;
Print("Per-group results:\n");;
Print("  Group     PhaseA   PhaseB    PhaseA_dt    PhaseB_dt    total_dt\n");;
Print("  -------   ------   ------    ----------   ----------   ----------\n");;
_n_A_ok := 0;; _n_A_crash := 0;;
_n_B_ok := 0;; _n_B_crash := 0;;
for _r in _results do
    Print("  SG#", String(_r.it), "      ",
          _OkStr(_r.phaseA_ok), "    ", _OkStr(_r.phaseB_ok), "    ",
          String(_r.dt_A), " ms      ",
          String(_r.dt_B), " ms      ",
          String(_r.dt_total), " ms\n");;
    if _r.phaseA_ok then _n_A_ok := _n_A_ok + 1;
                    else _n_A_crash := _n_A_crash + 1; fi;;
    if _r.phaseB_ok then _n_B_ok := _n_B_ok + 1;
                    else _n_B_crash := _n_B_crash + 1; fi;;
od;;
Print("----------------------------------------------------------------\n");;
Print("Phase A: ", _n_A_ok, " OK, ", _n_A_crash, " CRASH\n");;
Print("Phase B: ", _n_B_ok, " OK, ", _n_B_crash, " CRASH\n");;

# ---- 列出崩溃错误详情 ----
if _n_A_crash > 0 then
    Print("\nPhase A errors:\n");;
    for _r in _results do
        if not _r.phaseA_ok then
            Print("  SG#", String(_r.it), ": ", _r.phaseA_err, "\n");;
        fi;;
    od;;
fi;;
if _n_B_crash > 0 then
    Print("\nPhase B errors:\n");;
    for _r in _results do
        if not _r.phaseB_ok then
            Print("  SG#", String(_r.it), ": ", _r.phaseB_err, "\n");;
        fi;;
    od;;
fi;;
Print("================================================================\n\n");;

SptSetPrintStats();;

if _n_A_crash = 0 and _n_B_crash = 0 then
    Print("\nAll groups passed Phase A AND Phase B.\n");;
    FORCE_QUIT_GAP(0);;
else
    Print("\n", _n_A_crash, " Phase A crash(es), ",
          _n_B_crash, " Phase B crash(es). See log above.\n");;
    FORCE_QUIT_GAP(1);;
fi;;
