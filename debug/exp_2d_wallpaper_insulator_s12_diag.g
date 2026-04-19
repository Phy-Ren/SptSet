# 2D wallpaper groups (#2-#17) insulator s12 Phase A + Phase B 诊断 — 遵守实验铁律
# 从头开始，不加载 checkpoint，走 insulator 线 lib/ 源代码
# 模板：debug/exp_2d_wallpaper_insulator_diag.g (EZ 版本)
#       examples/fspt_2d_insulator_s12.g (insulator s12 Phase A 路径)
#       examples/fspt_2d_s12_ext.g       (superconductor s12 Phase B 路径)
#
# ============================================================
# 背景
# ------------------------------------------------------------
# 这是 EZ 版 (omega_=0) 的 s12 (spin-1/2 omega) 配套。
# s12 omega 通过 ww := 1/2 * Spin12Factor(2, it) 注入：
#     - omega_ != 0 → InsulatorSPTSpecSeq 中所有 omega_ * ... 项激活
#     - 关键: d_2^{1,1} 的 omega_(g1,g2)*n1(g3) 项不再归零
#     - 关键: d_2^{2,1} 的 omega_(g1,g2)*n2(g3,g4) 项不再归零
#     - 关键: d_2^{3,1} 的 omega_(g1,g2)*n3(g3,g4,g5) 项不再归零 (3+1D 才用)
#     - 新加: d_3^{0,3} 的 beta(omega_) cup n_0 项 → beta(omega_) 不再恒为 0
#       但本脚本是 2+1D，d_3^{0,3} 源在 (0,3) 目标 (3,1)，
#       而 (3,1) 在 2+1D 总度 4 上属于"上一层"，对 SS 总度 ≤ 3 没贡献
#       不过 PartialPurify 会顺路调到 d_3^{0,3} 的 cobdry 路径，
#       所以 depth 仍要 7（同 EZ 实验，详见 EZ 版 Trouble shooting [5]）
#
# 与 examples/fspt_2d_insulator_s12.g 的细微差别（同 EZ 改造）：
#   * examples 走 InsulatorSPTLayersVerbose + 手动 stacking + 手动 anomaly
#   * 本脚本走 InsulatorSPTLayersVerbose (Phase A 回归)
#               + SptSetSpecSeqResult(SS, 3, [1,2,3]) (Phase B 群结构, 首次)
#
# 物理图像 (s12 vs EZ):
#   EZ  (omega=0):    spinless (无 SOC) insulator + ARTI 对称, 退化 baseline
#   s12 (omega=1/2):  自旋 1/2 (有 SOC) insulator, 对应"realistic" 电子物质
#                     SOC 导致 omega_ 非零, K-theory 上对应不同 RHS spectrum
#                     物理上 [Z3,Z3,Z]+[Z2] 等 layer 的 ext 也会被改变
#
# ============================================================
# 实验设计
# ------------------------------------------------------------
#   * 16 个 wallpaper 群 (SG#2..#17)，逐一构建 InsulatorSPTSpecSeq
#   * omega_ = ww = 1/2 * Spin12Factor(2, it)  (s12 / spin-1/2 / SOC)
#   * auMap = u1cMap = DeterminantMat (与 EZ 版一致)
#   * Phase A: InsulatorSPTLayersVerbose(SS, 2)
#              对照 examples/fspt_2d_insulator_s12-result.txt 验证一致性
#   * Phase B: SptSetSpecSeqResult(SS, 3, [1,2,3]) + CanonicalForm + Display
#              这是 insulator s12 路径的 **群结构首次基线**
#              (examples 没有 fspt_2d_insulator_s12_ext.g, 故无现成对照)
#   * Phase A / Phase B 各自独立 CALL_WITH_CATCH，互不污染
#   * Phase A 崩 → 跳 Phase B
#
# ============================================================
# 运行方式
# ------------------------------------------------------------
#     ~/software/gap-4.13.1/gap \
#         -l "/home/user/xyren/gap-insulator/;/home/user/xyren/software/gap-4.13.1/" \
#         -r -b debug/exp_2d_wallpaper_insulator_s12_diag.g \
#         > debug/exp_2d_wallpaper_insulator_s12_diag.log 2>&1
#
# 也可设置环境变量 SG_RANGE 控制范围 (默认 [2..17]).
#
# ============================================================
# Trouble shooting / 历次运行记录
# ------------------------------------------------------------
#
# [1] 2026-04-19 设计阶段：参考 EZ 版 trouble shooting
# ----------------------------------------------------------------
#   - depth 必须用 7，参考 EZ 版 [5]：
#     d_2^{3,1} + d_3^{0,3} 一旦 install 就会被 PartialPurify 拉进 ComponentInf
#     的递归链路，最终查到 PseudoBoundary[7]。
#     s12 同样 install 了这两条公式，所以同样需要 depth=7。
#   - BreakOnError := false，避免 List 越界进 brk> 循环。
#
# [2] 2026-04-19 首次 s12 全 wallpaper 群运行：成功
# ----------------------------------------------------------------
#   总耗时: 1018.951 秒 (~17 分钟, 比 EZ 版本 930s 多 9.5%)
#   全部 16 群 OK, 0 CRASH (Phase A & Phase B 都通过)
#   并行统计: P1 96 parallel (147597ms) + 71 sequential (13134ms)
#              P2 26 calls (794604ms), max_m=8
#              P2b 0 calls (Phase B 内部 ext 都 sequential)
#
#   关键回归验证：与 examples/fspt_2d_insulator_s12-result.txt 比对
#                Empty/Complex fermion/Bosonic 三层 → 16/16 PERFECT MATCH
#                (此 baseline 只测 Phase A，Phase B 群结构无现成 ref)
#
#   Phase B 群结构 (insulator s12, dim=2 → SPT 总度=3):
#       SG#2 : [ 2, 4, 4, 4, 0 ]
#       SG#3 : [ 2, 4, 0 ]
#       SG#4 : [ 0 ]
#       SG#5 : [ 2, 0 ]
#       SG#6 : [ 2, 2, 2, 2, 4, 4, 4, 0 ]   ★ vs EZ [2,2,2,2,2,2,2,2,0]
#       SG#7 : [ 2, 4, 4, 0 ]
#       SG#8 : [ 2, 4, 0 ]
#       SG#9 : [ 2, 2, 4, 4, 0 ]            ★ vs EZ [2,2,2,2,4,0]
#       SG#10: [ 2, 4, 4, 8, 0 ]
#       SG#11: [ 2, 2, 2, 4, 8, 0 ]         ★ vs EZ [2,2,2,2,2,2,2,0]
#       SG#12: [ 2, 2, 8, 0 ]               ★ vs EZ [2,2,2,4,0]
#       SG#13: [ 3, 3, 3, 3, 3, 0 ]
#       SG#14: [ 3, 6, 0 ]
#       SG#15: [ 3, 6, 0 ]
#       SG#16: [ 3, 6, 12, 0 ]
#       SG#17: [ 2, 2, 12, 0 ]              ★ vs EZ [2,2,2,6,0]
#
#   物理解读: s12 omega ≠ 0 → InsulatorSPTSpecSeq 的 d_2^{1,1} / d_2^{2,1}
#       中所有 omega_(g1,g2)*n_q(g3,...) 项激活 → CF 与 Bos 之间获得
#       非平凡 cup-1 stacking obstruction → 部分 Z_2/Z_4 升 Z_4/Z_8 (SG#6,9,11,12,17)
#       这 5 个 wallpaper 群结构变化, 都带 reflection/glide (e.g. p2mm,
#       cmm, p4mm, p3m1, p6mm 等), 对应 spinful 系统中 SOC 引入新 anomaly.
#       其余 11 个群对 omega 不敏感 (CF 与 Bos 之间无非平凡 cup-1 配对).
#
#   慢群: SG#12 Phase B 424s (vs EZ 仅 8s), SG#17 Phase B 185s
#         原因: 这两个群是 cmm / p6mm, omega 激活后 d_2^{3,1} 在
#         class 1 PartialPurify 时算出大量 cobdry source generators
#         (8-9 个 vs 多数群 1-3 个)
#
# [3] 已知 LoadPackage warning（可忽略，同 EZ 版）
# ----------------------------------------------------------------
#     #E component `License'/`ArchiveURL'/... must be bound ...
#     #E Validation of package sptset ... failed
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
Print("2D wallpaper groups insulator s12 Phase A + Phase B diagnostic\n");;
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
Print("  s12 omega: ww = 1/2 * Spin12Factor(2, it) o PreImageElm(fSG)\n");;
Print("================================================================\n\n");;

# ============ 主循环 ============
_results := [];;
_t_total := NanosecondsSinceEpoch();;

for it in SG_RANGE do
    Print("\n################################################################\n");;
    Print("# SG#", it, " (wallpaper group, s12)\n");;
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

        # s12 omega: 1/2 * Spin12Factor pulled back to PcpGroup
        # 注意 1/2 是 insulator 必需 (omega_ 进 U(1) cocycle, 不是 Z_2 系数);
        # superconductor 版 (examples/fspt_2d_s12_ext.g) 不乘 1/2
        w := Spin12Factor(2, it);;
        ww := {g1, g2} -> 1/2 * w(PreImageElm(fSG, g1), PreImageElm(fSG, g2));;

        Print("Building spectral sequence (InsulatorSPTSpecSeq, s12, omega=ww)...\n");;
        _t := NanosecondsSinceEpoch();;
        SS := InsulatorSPTSpecSeq(R, f, f, ww);;
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
        Print("\nPhase B: SptSetSpecSeqResult(SS, 3, [1,2,3]) — insulator s12 群结构首次基线\n");;
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
Print("FINAL SUMMARY (insulator s12)\n");;
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
