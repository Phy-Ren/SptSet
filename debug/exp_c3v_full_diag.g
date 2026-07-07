SPTSET_PARALLEL_JOBS := 4;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

Print("================================================================\n");;
Print("C3v s12 (SG#156) FULL diagnostic trace\n");;
Print("  3 checkpoints: Bockstein, CanonicalForm, ZLMapInverse\n");;
Print("================================================================\n\n");;

_T0 := NanosecondsSinceEpoch();;
_DIAG_COUNT := 0;;

_elapsed := function()
    return Int((NanosecondsSinceEpoch() - _T0) / 1000000);
end;;

# ==============================================================
# CHECKPOINT 1: SptSetBockstein (Q/Z -> Z)
# ==============================================================
_orig_Bockstein := SptSetBockstein;;
MakeReadWriteGVar("SptSetBockstein");;
UnbindGlobal("SptSetBockstein");;
BindGlobal("SptSetBockstein", function(hapResolution, deg, gAction, v)
    local result, nonint, showlen;
    result := _orig_Bockstein(hapResolution, deg, gAction, v);
    nonint := Filtered([1..Length(result)], i -> not IsInt(result[i]));
    if Length(nonint) > 0 then
        _DIAG_COUNT := _DIAG_COUNT + 1;
        Print("\n!!! DIAG #", _DIAG_COUNT,
            " [", _elapsed(), " ms] CHECKPOINT 1: Bockstein => FRACTION\n");
        Print("    deg=", deg, ", input_len=", Length(v),
            ", output_len=", Length(result), "\n");
        Print("    non-int positions: ", nonint, "\n");
        Print("    non-int values:    ", result{nonint}, "\n");
        showlen := Minimum(20, Length(v));
        Print("    input v (first ", showlen, "): ", v{[1..showlen]}, "\n\n");
    fi;
    return result;
end);;

# ==============================================================
# CHECKPOINT 2: SptSetFpZModuleCanonicalForm (module -> SNF)
# ==============================================================
InstallMethod(SptSetFpZModuleCanonicalForm,
    "DIAG: pre-SNF fraction check",
    [IsSptSetFpZModuleRep],
    99,
    function(M)
        local rels, flat, nonint;
        if not SptSetFpZModuleIsZero(M) then
            rels := M!.relations;
            flat := Flat(rels);
            nonint := Filtered([1..Length(flat)], i -> not IsInt(flat[i]));
            if Length(nonint) > 0 then
                _DIAG_COUNT := _DIAG_COUNT + 1;
                Print("\n!!! DIAG #", _DIAG_COUNT,
                    " [", _elapsed(),
                    " ms] CHECKPOINT 2: CanonicalForm => FRACTION in relations\n");
                Print("    relations dims: ", DimensionsMat(rels), "\n");
                Print("    non-int count: ", Length(nonint),
                    " / ", Length(flat), "\n");
                Print("    non-int values (first 10): ",
                    flat{nonint}{[1..Minimum(10, Length(nonint))]}, "\n");
                Print("    diag of relations: ", DiagonalOfMat(rels), "\n\n");
            fi;
        fi;
        TryNextMethod();
    end);;

# ==============================================================
# CHECKPOINT 3: SptSetZLMapInverse (inverse map)
# ==============================================================
InstallMethod(SptSetZLMapInverse,
    "DIAG: fraction detector",
    [IsSptSetZLMapRep, IsRowVector],
    99,
    function(psi, v)
        local result, nonint;
        result := v * SptSetZLMapInverseMat(psi);
        nonint := Filtered([1..Length(result)], i -> not IsInt(result[i]));
        if Length(nonint) > 0 then
            _DIAG_COUNT := _DIAG_COUNT + 1;
            Print("\n!!! DIAG #", _DIAG_COUNT,
                " [", _elapsed(), " ms] CHECKPOINT 3: ZLMapInverse => FRACTION\n");
            Print("    non-int positions: ", nonint, "\n");
            Print("    non-int values:    ", result{nonint}, "\n\n");
        fi;
        return result;
    end);;

Print("All 3 diagnostic checkpoints installed.\n\n");;

# ==============================================================
# Set up C3v (space group #156) s12
# ==============================================================
Print("Setting up C3v s12 (SG#156)...\n");;
PG := PointGroup(SpaceGroupBBNWZ(3, 156));;
R := ResolutionFiniteGroup(PG, 7);;
Print("  Resolution dims: ");;
for _d in [0..6] do Print(R!.dimension(_d), " "); od;;
Print("\n  |G| = ", Order(PG), "\n\n");;

gens := GeneratorsOfGroup(PG);;
signs := List(gens, x -> [[DeterminantMat(x)]]);;
f := GroupHomomorphismByImagesNC(PG, GL(1, Integers), gens, signs);;
w2 := Spin12FactorForPointGroup(PG);;
ss := FermionSPTSpecSeq(R, f, w2);;

SPTSET_CHECKPOINT_HOOK := function() end;;

# ==============================================================
# Phase A: compute E-pages (classification)
# ==============================================================
Print("========== PHASE A: E-pages ==========\n\n");;
_tA := NanosecondsSinceEpoch();;
FermionSPTLayersVerbose(ss, 3);;
Print("\n  Phase A done: ",
    Int((NanosecondsSinceEpoch() - _tA) / 1000000), " ms\n");;
Print("  Fraction warnings so far: ", _DIAG_COUNT, "\n\n");;

Print("E_inf summary:\n");;
for _p in [1..4] do
    _q := 4 - _p;;
    _rmax := Maximum(_q + 2, _p + 1);;
    _Epq := SptSetSpecSeqComponent(ss, _rmax, _p, _q);;
    SptSetFpZModuleCanonicalForm(_Epq);;
    Print("  E_inf^{", _p, ",", _q, "}: ");;
    Display(_Epq);;
od;;
Print("\n");;

# ==============================================================
# Phase B: extension — wrapped in CALL_WITH_CATCH
# ==============================================================
Print("========== PHASE B: Extension ==========\n\n");;
_tB := NanosecondsSinceEpoch();;

_phaseB_result := CALL_WITH_CATCH(function()
    local M;
    M := SptSetSpecSeqResult(ss, 4, [2, 3, 4]);;
    Print("\n  Phase B done: ",
        Int((NanosecondsSinceEpoch() - _tB) / 1000000), " ms\n");;
    Print("  Total fraction warnings: ", _DIAG_COUNT, "\n\n");;

    if not SptSetFpZModuleIsZero(M) then
        SptSetFpZModuleCanonicalForm(M);;
        Print("Classification result:\n");;
        Display(M);;
    else
        Print("Classification result: trivial\n");;
    fi;;
    return true;
end, []);;

if _phaseB_result[1] = false then
    Print("\n!!! PHASE B CRASHED !!!\n");;
    Print("  Time at crash: ", _elapsed(), " ms\n");;
    Print("  Fraction warnings before crash: ", _DIAG_COUNT, "\n");;
    Print("  Error: ", _phaseB_result[2], "\n");;
fi;;

# ==============================================================
# Summary
# ==============================================================
Print("\n========== DIAGNOSTIC SUMMARY ==========\n");;
Print("  Total elapsed: ", _elapsed(), " ms\n");;
Print("  Total fraction warnings: ", _DIAG_COUNT, "\n");;
if _phaseB_result[1] = true then
    Print("  Status: SUCCESS\n");;
else
    Print("  Status: CRASHED\n");;
fi;;
Print("========================================\n");;

FORCE_QUIT_GAP(0);;
