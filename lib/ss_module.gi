DeclareRepresentation(
  "IsSptSetSpecSeqModuleRep",
  IsSptSetFpZModuleRep,
  ["specSeq", "pRange", "deg", "basis_classes", "components", "vector_embedings"]
);

BindGlobal(
  "TheFamilyOfSptSetSpecSeqModules",
  NewFamily("TheFamilyOfSptSetSpecSeqModules")
);

BindGlobal(
            "TheTypeSptSetSpecSeqModule",
            NewType(TheFamilyOfSptSetSpecSeqModules, IsSptSetSpecSeqModuleRep)
    );

InstallGlobalFunction
    (SptSetSpecSeqComponentEx,
    function(ss, p, q)
        local Epq, compEx, n, np, clnp, i, startIdx;
        Epq := SptSetSpecSeqComponentInf(ss, p, q);
        SptSetFpZModuleCanonicalForm(Epq);
        n := SptSetNumberOfGenerators(Epq);

        if not IsBound(ss!.compExPartial) then ss!.compExPartial := []; fi;
        if not IsBound(ss!.compExPartial[p+1]) then ss!.compExPartial[p+1] := []; fi;
        if IsBound(ss!.compExPartial[p+1][q+1]) then
            compEx := ss!.compExPartial[p+1][q+1];
            startIdx := Length(compEx.basis_classes) + 1;
        else
            compEx := rec();
            compEx.specSeq := ss;
            compEx.deg := p + q;
            compEx.pRange := [p];
            compEx.basis_classes := [];
            compEx.components := [];
            compEx.components[p] := Epq;
            compEx.vector_embedings := [];
            compEx.vector_embedings[p] := IdentityMat(n);
            startIdx := 1;
        fi;

        for i in [startIdx..n] do
            if SPTSET_CHECKPOINT_HOOK <> false then
                Print("    ComponentEx(", p, ",", q,
                  ") class ", i, "/", n, "...\n");
            fi;
            clnp := SptSetSpecSeqClassFromLevelCocycle(
                ss, compEx.deg, p, Epq!.generators[i]);
            Add(compEx.basis_classes, clnp);
            if SPTSET_CHECKPOINT_HOOK <> false then
                ss!.compExPartial[p+1][q+1] := compEx;
                SPTSET_CHECKPOINT_HOOK();
            fi;
        od;

        if IsBound(ss!.compExPartial[p+1]) and
           IsBound(ss!.compExPartial[p+1][q+1]) then
            Unbind(ss!.compExPartial[p+1][q+1]);
        fi;

        compEx.generators := IdentityMat(n);
        compEx.projection := IdentityMat(n);
        compEx.relations := Epq!.relations;
        return Objectify(TheTypeSptSetSpecSeqModule, compEx);
        
    end);

InstallGlobalFunction
    (SptSetSpecSeqModuleVectorToClass,
    function(M, a)
        local n, ss, deg, i, ai, cl, ci, pow;
        n := SptSetEmbedDimension(M);
        ss := M!.specSeq;
        deg := M!.deg;
        Assert(0, n = Length(a));

        cl := SptSetSpecSeqClassFromCochainNC(SptSetSpecSeqCochainZero(ss, deg));
        for i in [1..n] do
            ai := a[i];
            if ai = 0 then continue; fi;
            if ai < 0 then
                ci := -M!.basis_classes[i];
                ai := -ai;
            else
                ci := M!.basis_classes[i];
            fi;
            pow := ci;
            while ai > 0 do
                if ai mod 2 = 1 then
                    cl := cl + pow;
                fi;
                ai := Int(ai / 2);
                if ai > 0 then
                    pow := pow + pow;
                fi;
            od;
        od;
        return cl;
    end);

InstallGlobalFunction
    (SptSetSpecSeqModuleClassToLeadingVector,
    function(M, cl)
        local pRange, p, ss, deg, v;
        pRange := M!.pRange;
        # if Length(pRange) > 1 then
        #     Error("Not implemented");
        # fi;
        ss := M!.specSeq;
        deg := M!.deg;
           
        SptSetPurifySpecSeqClass(cl);
        p := LeadingLayer(cl);
        if p < First(pRange) then
            return fail;
        fi;

        if p > Last(pRange) then
            p := Last(pRange);
        fi;

        v := SptSetMapFromBarCocycle(ss!.brMap, p, ss!.spectrum[deg - p +1], cl!.cochain!.layers[p + 1]);
        # Display(v);
        # return v * M!.res_projections[p];
        return SptSetFpZModuleCanonicalElm(M!.components[p], v) * M!.vector_embedings[p];
    end);

InstallGlobalFunction
    (SptSetSpecSeqModuleClassToVector,
    function(M, cl)
        local pRange, p, ss, deg, v, vp, vnext, clnext;
        
        if SptSetFpZModuleIsZero(M) then
            return [];
        fi;

        pRange := M!.pRange;
        ss := M!.specSeq;
        deg := M!.deg;

        v := Zero([1..(SptSetEmbedDimension(M))]);
        repeat
            SptSetPurifySpecSeqClass(cl);
            p := LeadingLayer(cl);
            if p < First(pRange) then
                Error("Class beyond the p range");
            fi;
            if p > Last(pRange) then
                break;
            fi;

            vp := SptSetMapFromBarCocycle(ss!.brMap, p, ss!.spectrum[deg - p +1], cl!.cochain!.layers[p + 1]);
            #vnext := vp * M!.res_projections[p];
            vnext := SptSetFpZModuleCanonicalElm(M!.components[p], vp) * M!.vector_embedings[p];
            v := v + vnext;
            if p = Last(pRange) then break; fi;
            cl := cl - SptSetSpecSeqModuleVectorToClass(M, vnext);
            # Display([p, v]);
        until false;

        return v;
    end);

InstallGlobalFunction(SptSetSpecSeqModuleExtension,
function(M1, M2)
    local deg, pf, n1, n2, n, r1, r2, r, Emat, Pmat, Rmat, i, j, tj, vjn, cjn, vjnf, Mext, p;

    Assert(0, M1!.deg = M2!.deg);
    Assert(0, Length(M2!.pRange) = 1);
    Assert(0, Last(M1!.pRange) + 1 = M2!.pRange[1]);

    deg := M1!.deg;
    pf := M2!.pRange[1];

    SptSetFpZModuleCanonicalForm(M1);
    if SptSetFpZModuleIsZero(M1) then
        n1 := 0;
    else
        n1 := SptSetEmbedDimension(M1);
    fi;
    if SptSetFpZModuleIsZero(M2) then
        n2 := 0;
    else
        n2 := SptSetEmbedDimension(M2);
    fi;
    n := n1 + n2;


    if SptSetFpZModuleIsZero(M2) then
        Emat := M1!.generators;
        Pmat := M1!.projection;
        Rmat := M1!.relations;
    elif SptSetFpZModuleIsZero(M1) then
        Emat := M2!.generators;
        Pmat := M2!.projection;
        Rmat := M2!.relations;
    else


        r1 := SptSetNumberOfGenerators(M1);
        r2 := SptSetNumberOfGenerators(M2);
        r := r1 + r2;
        Emat := NullMat(r, n);
        Pmat := NullMat(n, r);
        Rmat := NullMat(r, r);

        for j in [1..r1] do
            for i in [1..n1] do
                Emat[j, i] := M1!.generators[j, i];
                Pmat[i, j] := M1!.projection[i, j];
            od;
        od;

        for j in [1..r1] do
            tj := M1!.relations[j, j];
            vjn := tj * M1!.generators[j];
            Rmat[j, j] := tj;
            if tj <> 0 then # torsion-free generators have no extension.
                cjn := SptSetSpecSeqModuleVectorToClass(M1, vjn);
                vjnf := SptSetSpecSeqModuleClassToLeadingVector(M2, cjn);
                # Display(["vjnf", vjnf]);
                Rmat[j]{[(r1+1)..r]} := vjnf;
            fi;
        od;

        for j in [(r1+1)..r] do
            for i in [(n1+1)..n] do
                Emat[j, i] := M2!.generators[j-r1, i-n1];
                Pmat[i, j] := M2!.projection[i-n1, j-r1];
            od;
            for i in [(r1+1)..r] do
                Rmat[j, i] := M2!.relations[j-r1, i-r1];
            od;
        od;
    fi;

    Mext := rec();
    Mext.specSeq := M1!.specSeq;
    Mext.deg := M1!.deg;
    Mext.pRange := Concatenation(M1!.pRange, M2!.pRange);
    Mext.basis_classes := Concatenation(M1!.basis_classes, M2!.basis_classes);
    Mext.components := M1!.components;
    Mext.vector_embedings := [];
    for p in M1!.pRange do
        Mext.vector_embedings[p] := List(M1!.vector_embedings[p], x -> Concatenation(x, Zero([1..n2])));
    od;
    #Display(["r1", r1]);
    # Display(["M2!.vec_emb", M2!.vector_embedings]);
    Mext.components[pf] := M2!.components[pf];
    Mext.vector_embedings[pf] := List(M2!.vector_embedings[pf], x -> Concatenation(Zero([1..n1]), x));
    # Display(["Mext!.vec_emb", Mext!.vector_embedings]);
    Mext.generators := Emat;
    Mext.projection := Pmat;
    Mext.relations := Rmat;

    return Objectify(TheTypeSptSetSpecSeqModule, Mext);

end);

# Old implementation: sequential extension with mixed generators.
# Kept for reference and comparison; use SptSetSpecSeqResult instead.
InstallGlobalFunction(SptSetSpecSeqResultOld,
function(ss, deg, pRange)
    local p, Epq, M;
    for p in pRange do
        Epq := SptSetSpecSeqComponentEx(ss, p, deg - p);
        if p = pRange[1] then
            M := Epq;
        else
            M := SptSetSpecSeqModuleExtension(M, Epq);
        fi;
    od;

    return M;
end);

# Layer-wise extension: compute each layer independently, then assemble.
#
# The physical stacking rules are between adjacent layers only.
# For each pair of adjacent layers (p, p+1), we independently compute
# how tj * (generator of layer p) projects into layer (p+1).
# This avoids the "mixed generator" problem where different Z-lifts
# of Z_n cochains can cause non-physical cancellations in the stacking
# twisters at higher layers.
#
# The full relation matrix is upper triangular:
#   R[i,i] = torsion of generator i
#   R[i,j] = extension coefficient (only for generators in adjacent layers)
# The Smith Normal Form of R gives the final group.
InstallGlobalFunction(SptSetSpecSeqResult,
function(ss, deg, pRange)
    local nLayers, Exs, nGens, totalGens, Rmat,
          offsets, pi, pj, p, j, k, tj, cjn, vjnf, M,
          saved_jobs, results, t_p2b, partial, doneRow;

    nLayers := Length(pRange);

    if not IsBound(ss!.resultPartial) then ss!.resultPartial := []; fi;
    if IsBound(ss!.resultPartial[deg+1]) then
        partial := ss!.resultPartial[deg+1];
        Exs := partial.Exs;
        nGens := partial.nGens;
    else
        partial := false;
        Exs := [];
        nGens := [];
    fi;

    # Step 1: get ComponentEx for each layer independently
    for pi in [1..nLayers] do
        if not IsBound(Exs[pi]) then
            p := pRange[pi];
            if SPTSET_CHECKPOINT_HOOK <> false then
                Print("  Result(deg=", deg, ") layer ", pi,
                  "/", nLayers, " (p=", p, ")...\n");
            fi;
            Exs[pi] := SptSetSpecSeqComponentEx(ss, p, deg - p);
            SptSetFpZModuleCanonicalForm(Exs[pi]);
            if SptSetFpZModuleIsZero(Exs[pi]) then
                nGens[pi] := 0;
            else
                nGens[pi] := SptSetNumberOfGenerators(Exs[pi]);
            fi;
            if SPTSET_CHECKPOINT_HOOK <> false then
                ss!.resultPartial[deg+1] := rec(
                    Exs := Exs, nGens := nGens, Rmat := false, doneRow := []);
                SPTSET_CHECKPOINT_HOOK();
            fi;
        else
            if not IsBound(nGens[pi]) then
                if SptSetFpZModuleIsZero(Exs[pi]) then
                    nGens[pi] := 0;
                else
                    nGens[pi] := SptSetNumberOfGenerators(Exs[pi]);
                fi;
            fi;
        fi;
    od;

    totalGens := Sum(nGens);
    if totalGens = 0 then
        if IsBound(ss!.resultPartial[deg+1]) then
            Unbind(ss!.resultPartial[deg+1]);
        fi;
        return SptSetZeroModule();
    fi;

    offsets := [];
    offsets[1] := 0;
    for pi in [2..nLayers] do
        offsets[pi] := offsets[pi-1] + nGens[pi-1];
    od;

    if partial <> false and partial.Rmat <> false then
        Rmat := partial.Rmat;
        doneRow := partial.doneRow;
    else
        Rmat := NullMat(totalGens, totalGens);
        doneRow := [];

        # Step 2: fill diagonal blocks
        for pi in [1..nLayers] do
            for j in [1..nGens[pi]] do
                Rmat[offsets[pi] + j][offsets[pi] + j] :=
                    Exs[pi]!.relations[j][j];
            od;
        od;
    fi;

    # Step 3: fill off-diagonal blocks
    for pi in [1..(nLayers-1)] do
        if nGens[pi] = 0 then
            continue;
        fi;

        if SPTSET_PARALLEL_JOBS > 0 and SPTSET_PHASE2_ENABLED
           and nGens[pi] >= 2 and IsBoundGlobal("ParListByFork") then
            saved_jobs := SPTSET_PARALLEL_JOBS;
            SPTSET_PARALLEL_JOBS := Maximum(0, Int(saved_jobs / nGens[pi]));
            t_p2b := NanosecondsSinceEpoch();

            results := ParListByFork([1..nGens[pi]], function(jj)
                local ltj, lcjn, lpj, lvjnf;
                ltj := Exs[pi]!.relations[jj][jj];
                if ltj = 0 then return [0, []]; fi;
                lcjn := SptSetSpecSeqModuleVectorToClass(
                    Exs[pi], ltj * Exs[pi]!.generators[jj]);
                for lpj in [(pi+1)..nLayers] do
                    if nGens[lpj] = 0 then continue; fi;
                    lvjnf := SptSetSpecSeqModuleClassToLeadingVector(
                        Exs[lpj], lcjn);
                    if lvjnf <> fail then
                        return [lpj, lvjnf];
                    fi;
                od;
                return [0, []];
            end, rec(NumberJobs := Minimum(nGens[pi], saved_jobs)));

            SPTSET_PARALLEL_JOBS := saved_jobs;
            SPTSET_STATS.p2b_calls := SPTSET_STATS.p2b_calls + 1;
            SPTSET_STATS.p2b_time := SPTSET_STATS.p2b_time
              + Int((NanosecondsSinceEpoch()-t_p2b)/1000000);
            if nGens[pi] > SPTSET_STATS.p2b_max_ngens then
              SPTSET_STATS.p2b_max_ngens := nGens[pi]; fi;

            for j in [1..nGens[pi]] do
                if results[j][1] > 0 then
                    pj := results[j][1];
                    vjnf := results[j][2];
                    for k in [1..nGens[pj]] do
                        Rmat[offsets[pi] + j][offsets[pj] + k] := vjnf[k];
                    od;
                fi;
            od;
            if SPTSET_CHECKPOINT_HOOK <> false then
                Print("    ext layer ", pi,
                  " all ", nGens[pi], " gens done (parallel), saving...\n");
                ss!.resultPartial[deg+1] := rec(
                    Exs := Exs, nGens := nGens,
                    Rmat := Rmat, doneRow := doneRow);
                SPTSET_CHECKPOINT_HOOK();
            fi;
        else
            for j in [1..nGens[pi]] do
                if IsBound(doneRow[offsets[pi] + j]) then
                    continue;
                fi;
                tj := Exs[pi]!.relations[j][j];
                if tj <> 0 then
                    if SPTSET_CHECKPOINT_HOOK <> false then
                        Print("    ext layer ", pi, " gen ", j,
                          "/", nGens[pi], "...\n");
                    fi;
                    cjn := SptSetSpecSeqModuleVectorToClass(
                        Exs[pi], tj * Exs[pi]!.generators[j]);
                    for pj in [(pi+1)..nLayers] do
                        if nGens[pj] = 0 then
                            continue;
                        fi;
                        vjnf := SptSetSpecSeqModuleClassToLeadingVector(
                            Exs[pj], cjn);
                        if vjnf <> fail then
                            for k in [1..nGens[pj]] do
                                Rmat[offsets[pi] + j][offsets[pj] + k] := vjnf[k];
                            od;
                            break;
                        fi;
                    od;
                fi;
                doneRow[offsets[pi] + j] := true;
                if SPTSET_CHECKPOINT_HOOK <> false then
                    ss!.resultPartial[deg+1] := rec(
                        Exs := Exs, nGens := nGens,
                        Rmat := Rmat, doneRow := doneRow);
                    SPTSET_CHECKPOINT_HOOK();
                fi;
            od;
        fi;
    od;

    if IsBound(ss!.resultPartial[deg+1]) then
        Unbind(ss!.resultPartial[deg+1]);
    fi;

    # Step 4: build FpZModule from the relation matrix
    M := SptSetFpZModuleEPR(
        IdentityMat(totalGens),
        IdentityMat(totalGens),
        Rmat);

    return M;
end);

InstallMethod(SptSetMapInducedByGroupHomomorphism,
    "Map between SpecSeq modules induced by a group homomorphism",
    [IsSptSetSpecSeqModuleRep, IsSptSetSpecSeqModuleRep, IsGroupHomomorphism],
    function(M, N, fHG)
        local ssM, ssN, m, n, fA, i, clM, ccN, clN, vecN;

        if SptSetFpZModuleIsZero(M) or SptSetFpZModuleIsZero(N) then
            return SptSetZeroMap(M, N);
        fi;

        ssM := M!.specSeq;
        ssN := N!.specSeq;
        m := Length(M!.generators);
        n := Length(N!.generators);

        fA := [];

        for i in [1..m] do
            clM := SptSetSpecSeqModuleVectorToClass(M, M!.generators[i]);
            ccN := SptSetMapSpecSeqCochainByGroupHomomorphism(clM!.cochain, ssN, fHG);
            clN := SptSetSpecSeqClassFromCochainNC(ccN);
            vecN := SptSetSpecSeqModuleClassToVector(N, clN);
            fA[i] := vecN * N!.projection;
        od;
        
        return SptSetZLMapByImages(M, N, fA);
    end);