# 3D 点群 FSPT STC 批量计算 — EZ 模式 (spinless, with p+ip)
# 基于 debug 线 lib/ 源代码，遵守实验铁律
# 遍历全部 32 个 3D 点群，输出群结构（对应 PhysRevX.15.031029 Table 3 右列）
#
# 运行: cd ~/gap-debug && gap -o 48G -l ... pkg/SptSet/examples/fspt_3d_ez_all.g

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

# ============ 铁律 1: 验证加载的是 debug 线 ============
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Print("================================================================\n");;
Print("3D Point Group FSPT STC — EZ mode (spinless, with p+ip)\n");;
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
Print("================================================================\n\n");;

Read(Concatenation(_sptset_path, "/examples/point_group_res.g"));;;

Print("Total point groups to compute: ", Length(PtGrpNames), "\n");;
Print("============================================================\n\n");;

for i in [1..Length(PtGrpNames)] do
    _t0 := NanosecondsSinceEpoch();;
    Print("--- [", i, "/", Length(PtGrpNames), "] ", PtGrpNames[i], " ---\n");;

    PG := PtGrps[i];;

    # Build resolution with dim=8 (dim=7 from point_group_res.g is insufficient)
    Print("  Building resolution (dim=8, |G|=", Order(PG), ")...");;
    _tR := NanosecondsSinceEpoch();;
    if PtGrpNames[i] = "D4h" then
        D4h := DirectProduct(DihedralGroup(8), Group([(1,2)]));;
        f_iso := IsomorphismGroups(D4h, PG);;
        R := ResolutionFiniteGroup(D4h, 8);;
        R!.group := PG;;
        R!.elts := List(R!.elts, x -> Image(f_iso, x));;
    elif PtGrpNames[i] = "Oh" then
        Oh := DirectProduct(SymmetricGroup(4), Group([(1,2)]));;
        f_iso := IsomorphismGroups(Oh, PG);;
        R := ResolutionFiniteGroup(Oh, 8);;
        R!.group := PG;;
        R!.elts := List(R!.elts, x -> Image(f_iso, x));;
    else
        R := ResolutionFiniteGroup(PG, 9);;
    fi;;
    _dtR := Int((NanosecondsSinceEpoch() - _tR) / 1000000);;
    Print(" done (", _dtR, " ms)\n");;

    gens := GeneratorsOfGroup(PG);;
    signs := List(gens, x -> [[DeterminantMat(x)]]);;
    f := GroupHomomorphismByImagesNC(PG, GL(1, Integers), gens, signs);;
    ss := FermionEZSPTSpecSeq(R, f);;

    # Phase A: Classification
    _tA := NanosecondsSinceEpoch();;
    layers := FermionSPTLayers(ss, 3);
    _dtA := Int((NanosecondsSinceEpoch() - _tA) / 1000000);;

    Print("  Layers: ");;
    Display(layers);;

    # Phase B: Group structure (with p+ip, pRange=[1,2,3,4])
    _tB := NanosecondsSinceEpoch();;
    M := SptSetSpecSeqResult(ss, 4, [1,2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
    _dtB := Int((NanosecondsSinceEpoch() - _tB) / 1000000);;

    Print("  STC: ");;
    Display(M);;

    _dt := Int((NanosecondsSinceEpoch() - _t0) / 1000000);;
    Print("  Time: Phase A=", _dtA, "ms, Phase B=", _dtB, "ms, Total=", _dt, "ms\n\n");;
od;

Print("============================================================\n");;
Print("ALL DONE: ", Length(PtGrpNames), " point groups (EZ mode)\n");;
SptSetPrintStats();;
FORCE_QUIT_GAP(0);;
