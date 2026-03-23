SPTSET_PARALLEL_JOBS := 4;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

Print("================================================================\n");;
Print("C4v s12 clean diagnostic trace\n");;
Print("  no workspace, no code changes, only observation\n");;
Print("================================================================\n\n");;

_T0 := NanosecondsSinceEpoch();;
_DIAG_COUNT := 0;;

_elapsed := function()
    return Int((NanosecondsSinceEpoch() - _T0) / 1000000);
end;;

# ==============================================================
# Diagnostic wrapper: SptSetZLMapInverse
#
# Intercepts every call to SptSetZLMapInverse.
# When the result contains non-integer values, prints:
#   - domain/codomain dimensions and torsion
#   - SNF of the map matrix (reveals d entries that generate 1/d)
#   - input vector, output vector, positions of fractions
#
# DOES NOT change computation: the return value is identical
# to the original method (v * InverseMat).
# ==============================================================
InstallMethod(SptSetZLMapInverse,
    "DIAG: fraction detector",
    [IsSptSetZLMapRep, IsRowVector],
    99,
    function(psi, v)
        local result, nonint, A, R2, diagR2, idsR2, tA, snf_diag,
              cod_rels, dom_dim, cod_dim;

        result := v * SptSetZLMapInverseMat(psi);

        nonint := Filtered([1..Length(result)], i -> not IsInt(result[i]));
        if Length(nonint) > 0 then
            _DIAG_COUNT := _DIAG_COUNT + 1;
            dom_dim := DimensionsMat(psi!.domain!.generators)[2];
            cod_dim := DimensionsMat(psi!.codomain!.generators)[2];

            Print("\n");
            Print("!!! DIAG #", _DIAG_COUNT,
                " [", _elapsed(), " ms] SptSetZLMapInverse => FRACTION\n");
            Print("    domain  embed_dim=", dom_dim, "\n");
            Print("    codomain embed_dim=", cod_dim, "\n");

            cod_rels := DiagonalOfMat(psi!.codomain!.relations);
            Print("    codomain torsion diag: ", cod_rels, "\n");

            if not SptSetFpZModuleIsCanonical(psi!.codomain) then
                SptSetFpZModuleCanonicalForm(psi!.codomain);
            fi;
            A := psi!.domain!.generators * psi!.B * psi!.codomain!.projection;
            R2 := StructuralCopy(psi!.codomain!.relations);
            diagR2 := DiagonalOfMat(R2);
            idsR2 := PositionsProperty(diagR2, x -> x <> 0);
            R2 := R2{idsR2};
            tA := StructuralCopy(A);
            Append(tA, R2);
            snf_diag := DiagonalOfMat(
                SmithNormalFormIntegerMatTransforms(tA).normal);
            Print("    augmented [A;R2] SNF diag: ", snf_diag, "\n");
            Print("    input  v = ", v, "\n");
            Print("    output   = ", result, "\n");
            Print("    non-int positions: ", nonint, "\n");
            Print("    non-int values:    ", result{nonint}, "\n\n");
        fi;

        return result;
    end);;

Print("Diagnostic wrapper installed.\n\n");;

# ==============================================================
# Set up C4v (space group #99) s12
# ==============================================================
Print("Setting up C4v s12...\n");;
PG := PointGroup(SpaceGroupBBNWZ(3, 99));;
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

# Print E_inf for each layer
Print("E_inf summary:\n");;
for _p in [2..4] do
    _q := 4 - _p;;
    _rmax := Maximum(_q + 2, _p + 1);;
    _Epq := SptSetSpecSeqComponent(ss, _rmax, _p, _q);;
    SptSetFpZModuleCanonicalForm(_Epq);;
    Print("  E_inf^{", _p, ",", _q, "}: ");;
    Display(_Epq);;
od;;
Print("\n");;

# ==============================================================
# Phase B: extension (ComponentEx)
# ==============================================================
Print("========== PHASE B: Extension ==========\n\n");;
_tB := NanosecondsSinceEpoch();;
M := SptSetSpecSeqResult(ss, 4, [2, 3, 4]);;
Print("\n  Phase B done: ",
    Int((NanosecondsSinceEpoch() - _tB) / 1000000), " ms\n");;
Print("  Total fraction warnings: ", _DIAG_COUNT, "\n\n");;

if not SptSetFpZModuleIsZero(M) then
    SptSetFpZModuleCanonicalForm(M);;
    Print("Classification result:\n");;
    Display(M);;
fi;;

# ==============================================================
# Summary
# ==============================================================
Print("\n========== DIAGNOSTIC SUMMARY ==========\n");;
Print("  Total elapsed: ", _elapsed(), " ms\n");;
Print("  Total fraction warnings: ", _DIAG_COUNT, "\n");;
Print("========================================\n");;

FORCE_QUIT_GAP(0);;
