# 3D 点群 EZ 补算 — 仅第25-30组 (D6h, T, Th, O, Td, Oh)
# dim=8, 高内存, 追加到全量log

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
if PositionSublist(_sptset_path, "gap-debug") = fail then
    Print("FATAL: not debug version!\n");;
    FORCE_QUIT_GAP(1);;
fi;;

SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;

Read(Concatenation(_sptset_path, "/examples/point_group_res.g"));;;

_start := 25;;
_end := Length(PtGrpNames);;

for i in [_start.._end] do
    _t0 := NanosecondsSinceEpoch();;
    Print("--- [", i, "/", _end, "] ", PtGrpNames[i], " ---\n");;

    PG := PtGrps[i];;
    Print("  Building resolution (dim=8, |G|=", Order(PG), ")...");;
    _tR := NanosecondsSinceEpoch();;
    if PtGrpNames[i] = "Oh" then
        Oh := DirectProduct(SymmetricGroup(4), Group([(1,2)]));;
        f_iso := IsomorphismGroups(Oh, PG);;
        R := ResolutionFiniteGroup(Oh, 8);;
        R!.group := PG;;
        R!.elts := List(R!.elts, x -> Image(f_iso, x));;
    else
        R := ResolutionFiniteGroup(PG, 8);;
    fi;;
    _dtR := Int((NanosecondsSinceEpoch() - _tR) / 1000000);;
    Print(" done (", _dtR, " ms)\n");;

    gens := GeneratorsOfGroup(PG);;
    signs := List(gens, x -> [[DeterminantMat(x)]]);;
    f := GroupHomomorphismByImagesNC(PG, GL(1, Integers), gens, signs);;
    ss := FermionEZSPTSpecSeq(R, f);;

    _tA := NanosecondsSinceEpoch();;
    layers := FermionSPTLayers(ss, 3);
    _dtA := Int((NanosecondsSinceEpoch() - _tA) / 1000000);;
    Print("  Layers: ");;
    Display(layers);;

    _tB := NanosecondsSinceEpoch();;
    M := SptSetSpecSeqResult(ss, 4, [1,2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
    _dtB := Int((NanosecondsSinceEpoch() - _tB) / 1000000);;

    Print("  STC: ");;
    Display(M);;

    _dt := Int((NanosecondsSinceEpoch() - _t0) / 1000000);;
    Print("  Time: Phase A=", _dtA, "ms, Phase B=", _dtB, "ms, Total=", _dt, "ms\n\n");;
od;

Print("TAIL DONE: groups ", _start, "-", _end, "\n");;
SptSetPrintStats();;
FORCE_QUIT_GAP(0);;
