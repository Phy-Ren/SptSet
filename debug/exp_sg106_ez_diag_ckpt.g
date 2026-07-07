# SG#106 (P4₂bc) EZ diagnostic with CHECKPOINT — debug line
# Resume: gap -L ~/checkpoints/sg106_diag.ws -b this_script.g

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

# Verify debug line
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Print("================================================================\n");;
Print("SG#106 (P4₂bc) EZ diagnostic [CHECKPOINT ENABLED]\n");;
Print("  SptSet loaded from: ", _sptset_path, "\n");;
if PositionSublist(_sptset_path, "gap-debug") = fail then
    Print("  FATAL: NOT loading debug version! Aborting.\n");;
    FORCE_QUIT_GAP(1);;
fi;;
Print("  OK: debug version confirmed.\n");;

CKPT_FILE := "~/checkpoints/sg106_diag.ws";;
CKPT_SAVE := function()
    SaveWorkspace(Concatenation(CKPT_FILE, ".tmp"));;
    Exec(Concatenation("mv -f ", CKPT_FILE, ".tmp ", CKPT_FILE));;
end;;

SPTSET_PARALLEL_JOBS := 26;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;
Print("  Parallel: JOBS=", SPTSET_PARALLEL_JOBS,
      " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
      " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");;
Print("================================================================\n\n");;

# --- Resume or fresh start ---
if not IsBound(CKPT_STEP) then
    CKPT_STEP := 0;;

    Read(Concatenation(
        GAPInfo.PackagesInfo.sptset[1].InstallationPath,
        "/examples/res_space_group.g"));;

    Print("Building resolution for SG#100...\n");;
    _t := NanosecondsSinceEpoch();;
    SG := SpaceGroupBBNWZ(3, 106);;
    fSG := IsomorphismPcpGroup(SG);;
    SG1 := Image(fSG);;
    R := Resolution3DSpaceGroup(fSG, 9);;
    Print("  Resolution built in ", Int((NanosecondsSinceEpoch()-_t)/1000000), " ms\n");;
    Print("  Dimensions: ");;
    for _d in [0..8] do Print(R!.dimension(_d), " "); od;;
    Print("\n\n");;

    gs := GeneratorsOfGroup(SG);;
    f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
        List(gs, x -> Image(fSG, x)),
        List(gs, x -> [[DeterminantMat(x)]]));;

    Print("Building spectral sequence (EZ, spinless)...\n");;
    SS := FermionEZSPTSpecSeq(R, f);;
    Print("  Spectral sequence created.\n\n");;
else
    Print("RESUMED from checkpoint at step ", CKPT_STEP, "\n\n");;
fi;;

_LAYER_NAMES := ["Bosonic:", "Complex fermion:", "Majorana:", "p+ip:"];;

# ============ Phase A: Classification ============
Print("Phase A: Classification\n");;
Print("------------------------------------------------------------\n");;
_tA := NanosecondsSinceEpoch();;
_page_count := 0;;

for _p in [1..4] do
    _q := 4 - _p;;
    if _q >= 0 and _q <= 3 then
        _rmax := Maximum(_q+2, _p+1);;
        for _r in [2.._rmax] do
            _page_count := _page_count + 1;;
            if _page_count <= CKPT_STEP then continue; fi;;
            Print("[", _page_count, "] E^{", _p, ",", _q, "}_", _r, "...");;
            _t := NanosecondsSinceEpoch();;
            _Erpq := SptSetSpecSeqComponent(SS, _r, _p, _q);;
            SptSetFpZModuleCanonicalForm(_Erpq);;
            _dt := Int((NanosecondsSinceEpoch() - _t) / 1000000);;
            Print(" = ");;
            ViewObj(_Erpq);;
            Print("  (", _dt, " ms)\n");;
            if SptSetFpZModuleIsZero(_Erpq) then
                Print("  -> ZERO, skipping higher r\n\n");;
                CKPT_STEP := _page_count;;
                Print("  [ckpt save #", CKPT_STEP, "]...");;
                CKPT_SAVE();;
                Print(" done.\n");;
                break;;
            fi;;
            _ngens := SptSetNumberOfGenerators(_Erpq);;
            Print("  Generators: ", _ngens,
                  ", torsion: ", List([1.._ngens],
                    function(j) return _Erpq!.relations[j][j]; end), "\n\n");;
            CKPT_STEP := _page_count;;
            Print("  [ckpt save #", CKPT_STEP, "]...");;
            CKPT_SAVE();;
            Print(" done.\n");;
        od;;
    fi;;
od;;

_dtA := Int((NanosecondsSinceEpoch()-_tA)/1000000);;
Print("============================================================\n");;
Print("Phase A COMPLETE in ", _dtA, " ms\n");;
Print("============================================================\n\n");;

# ============ Phase B: Group Structure ============
Print("Phase B: Computing group structure...\n");;
Print("  SptSetSpecSeqResult(SS, 4, [1,2,3,4])\n");;
Print("------------------------------------------------------------\n");;
_tB := NanosecondsSinceEpoch();;
_phaseB_ok := CALL_WITH_CATCH(function()
    M := SptSetSpecSeqResult(SS, 4, [1,2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
end, []);;
_dtB := Int((NanosecondsSinceEpoch()-_tB)/1000000);;

if _phaseB_ok[1] then
    Print("\n============================================================\n");;
    Print("Phase B COMPLETE in ", _dtB, " ms\n");;
    Print("Group structure: ");;
    Display(M);;
    Print("============================================================\n\n");;
    CKPT_STEP := 999;;
    CKPT_SAVE();;
    Print("[ckpt save — ALL DONE]\n");;
else
    Print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");;
    Print("Phase B CRASHED after ", _dtB, " ms\n");;
    Print("Error: ", _phaseB_ok[2], "\n");;
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
            _Erpq := SptSetSpecSeqComponent(SS, _r, _p, _q);;
            SptSetFpZModuleCanonicalForm(_Erpq);;
            if SptSetFpZModuleIsZero(_Erpq) then break; fi;;
        od;;
        Print("  ", _LAYER_NAMES[_q+1], " E^{", _p, ",", _q, "}_inf = ");;
        Display(_Erpq);;
    fi;;
od;;

Print("\nTotal time: Phase A=", _dtA, "ms, Phase B=", _dtB, "ms, Total=",
      _dtA + _dtB, "ms\n");;

SptSetPrintStats();;

FORCE_QUIT_GAP(0);;
