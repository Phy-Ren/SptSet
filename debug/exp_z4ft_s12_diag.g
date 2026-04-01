# Z_4^{f,T} s12 full diagnostic — 遵守实验铁律
# 从头开始，不加载 checkpoint，走 debug 线 lib/ 源代码
# 模板：C4v s12 成功实验
#
# 物理：G_f = Z_4^{f,T}，即 G_b = Z_2^T，T^2 = P_f
#   s_1 = m_1（T 反幺正），w_2 = m_1^2（非平凡 2-cocycle）
# 预期结果：
#   E_inf 全部 Z_2（所有 d_r = 0）
#   pRange=[1,2,3,4]: Z_16
#   pRange=[2,3,4]:   Z_8

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

# ============ 铁律 1: 验证加载的是 debug 线 ============
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Print("================================================================\n");;
Print("Z_4^{f,T} (G_b=Z_2^T) s12 diagnostic\n");;
Print("  SptSet loaded from: ", _sptset_path, "\n");;
if PositionSublist(_sptset_path, "gap-debug") = fail then
    Print("  FATAL: NOT loading debug version! Aborting.\n");;
    FORCE_QUIT_GAP(1);;
fi;;
Print("  OK: debug version confirmed.\n");;

# ============ 铁律 4: 并行计算 ============
SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;
Print("  Parallel: JOBS=", SPTSET_PARALLEL_JOBS,
      " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
      " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");;

# ============ 铁律 3: 诊断已加入 lib/ 源码 (12 checkpoints) ============
Print("  Diagnostics (12 points in lib/ source code):\n");;
Print("    Bockstein, ZLMapInverse, CanonicalForm, PurifyClass,\n");;
Print("    PartialPurify-stack, PurifyCobdry-stack, PartialPurifySSClass,\n");;
Print("    PartialConstruct, BuildDeriv-par, BuildDeriv-seq,\n");;
Print("    ClassToLeadVec, ModExt-vjnf\n");;
Print("================================================================\n\n");;

# ============ 铁律 2: 群构造 ============
#
# G_b = Z_2 = <T | T^2 = 1>
# GAP 中用置换 (1,2) 表示 T，它的平方 (1,2)^2 = () = 恒等
#
Print("Setting up Z_4^{f,T} (G_b = Z_2^T, s12 mode)...\n");;
_t := NanosecondsSinceEpoch();;
G := Group([(1,2)]);;
Print("  G_b = Z_2, |G| = ", Order(G), ", generators: ", GeneratorsOfGroup(G), "\n");;

R := ResolutionFiniteGroup(G, 9);;
Print("  Resolution built in ", Int((NanosecondsSinceEpoch()-_t)/1000000), " ms\n");;
Print("  Dimensions: ");;
for _d in [0..8] do Print(R!.dimension(_d), " "); od;;
Print("\n");;

# f 编码反幺正信息（与已有例子 ap_z4_z2t.g 一致）
# s_1(T) = 1，即 T 反幺正 → f(T) = [[-1]]
f := GroupHomomorphismByImagesNC(G, GL(1, Integers), [(1,2)], [ [[-1]] ]);;
Print("  f: T -> [[-1]] (anti-unitary)\n");;

# w 是 H^2(Z_2, Z_2) 的非平凡元素（与已有例子命名一致，用 w 不用 w2）
# 物理：T^2 = P_f → 扩展 1 → Z_2^f → Z_4 → Z_2 → 1 非平凡
# 公式与 ap_z4_z2t.g 第 8-14 行完全一致
w := function(g1, g2)
    if 1^g1 = 2 then
        return (1 - (g2^f)[1][1])/2;
    else
        return 0;
    fi;
end;;
Print("  w: w(T,T)=", w((1,2),(1,2)), " w(T,e)=", w((1,2),()), " (non-trivial)\n");;

ss := FermionSPTSpecSeq(R, f, w);;
Print("  Spectral sequence (s12) created.\n\n");;

# ============ Phase A: Classification ============
_LAYER_NAMES := ["Bosonic:", "Complex fermion:", "Majorana:", "p+ip:"];;
Print("Phase A: Classification (with p+ip, zero-module early stop)\n");;
Print("------------------------------------------------------------\n");;
_tA := NanosecondsSinceEpoch();;
_page_count := 0;;

for _p in [1..4] do
    _q := 4 - _p;;
    if _q >= 0 and _q <= 3 then
        _rmax := Maximum(_q+2, _p+1);;
        Print("--- Layer ", _LAYER_NAMES[_q+1], " (p=", _p, ", q=", _q,
              ", rmax=", _rmax, ") ---\n");;
        for _r in [2.._rmax] do
            _page_count := _page_count + 1;;
            Print("[", _page_count, "] E^{", _p, ",", _q, "}_", _r, "...");;
            _t := NanosecondsSinceEpoch();;
            _Erpq := SptSetSpecSeqComponent(ss, _r, _p, _q);;
            SptSetFpZModuleCanonicalForm(_Erpq);;
            _dt := Int((NanosecondsSinceEpoch() - _t) / 1000000);;
            Print(" = ");;
            ViewObj(_Erpq);;
            Print("  (", _dt, " ms)\n");;
            if SptSetFpZModuleIsZero(_Erpq) then
                Print("  -> ZERO, skipping higher r for (", _p, ",", _q, ")\n\n");;
                break;;
            fi;;
            _ngens := SptSetNumberOfGenerators(_Erpq);;
            Print("  Generators: ", _ngens,
                  ", torsion: ", List([1.._ngens],
                    function(j) return _Erpq!.relations[j][j]; end), "\n\n");;
        od;;
    fi;;
od;;

_dtA := Int((NanosecondsSinceEpoch()-_tA)/1000000);;
Print("============================================================\n");;
Print("Phase A COMPLETE in ", _dtA, " ms\n");;
Print("============================================================\n\n");;

# ============ Phase B1: Without p+ip (safe, expected Z_8) ============
Print("Phase B1: Without p+ip [2,3,4]...\n");;
Print("  Expected: Z_8\n");;
Print("------------------------------------------------------------\n");;
_tB1 := NanosecondsSinceEpoch();;
_phaseB1_ok := CALL_WITH_CATCH(function()
    M1 := SptSetSpecSeqResult(ss, 4, [2,3,4]);;
    SptSetFpZModuleCanonicalForm(M1);;
end, []);;
_dtB1 := Int((NanosecondsSinceEpoch()-_tB1)/1000000);;

if _phaseB1_ok[1] then
    Print("\n============================================================\n");;
    Print("Phase B1 COMPLETE in ", _dtB1, " ms\n");;
    Print("Group structure (without p+ip): ");;
    Display(M1);;
    Print("============================================================\n\n");;
else
    Print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");;
    Print("Phase B1 CRASHED after ", _dtB1, " ms\n");;
    Print("Error: ", _phaseB1_ok[2], "\n");;
    Print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n");;
fi;;

# ============ Phase B2: Full with p+ip (may crash, expected Z_16) ============
Print("Phase B2: With p+ip [1,2,3,4]...\n");;
Print("  Expected: Z_16\n");;
Print("------------------------------------------------------------\n");;
_tB2 := NanosecondsSinceEpoch();;
_phaseB2_ok := CALL_WITH_CATCH(function()
    M2 := SptSetSpecSeqResult(ss, 4, [1,2,3,4]);;
    SptSetFpZModuleCanonicalForm(M2);;
end, []);;
_dtB2 := Int((NanosecondsSinceEpoch()-_tB2)/1000000);;

if _phaseB2_ok[1] then
    Print("\n============================================================\n");;
    Print("Phase B2 COMPLETE in ", _dtB2, " ms\n");;
    Print("Group structure (with p+ip): ");;
    Display(M2);;
    Print("============================================================\n\n");;
else
    Print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");;
    Print("Phase B2 CRASHED after ", _dtB2, " ms\n");;
    Print("Error: ", _phaseB2_ok[2], "\n");;
    Print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n");;
fi;;

# ============ Final Summary ============
Print("Classification layers (E_inf from cache):\n");;
for _p in [1..4] do
    _q := 4 - _p;;
    if _q >= 0 and _q <= 3 then
        _rmax := Maximum(_q+2, _p+1);;
        _Erpq := SptSetZeroModule();;
        for _r in [2.._rmax] do
            _Erpq := SptSetSpecSeqComponent(ss, _r, _p, _q);;
            SptSetFpZModuleCanonicalForm(_Erpq);;
            if SptSetFpZModuleIsZero(_Erpq) then break; fi;;
        od;;
        Print("  ", _LAYER_NAMES[_q+1], " E^{", _p, ",", _q, "}_inf = ");;
        Display(_Erpq);;
    fi;;
od;;

Print("\nTotal time: Phase A=", _dtA, "ms, Phase B1=", _dtB1, "ms, Phase B2=",
      _dtB2, "ms, Total=", _dtA + _dtB1 + _dtB2, "ms\n");;

SptSetPrintStats();;

FORCE_QUIT_GAP(0);;
