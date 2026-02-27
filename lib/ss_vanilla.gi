DeclareRepresentation(
  "IsSptSetSpecSeqVanillaRep",
  IsSptSetSpecSeqRep,
  ["resolution", "brMap", "spectrum", "bdry", "addTwister",
   "cochainTypes", "classTypes"]
);

BindGlobal(
  "TheTypeSptSetVanillaSpecSeq",
  NewType(TheFamilyOfSptSetSpecSeqs, IsSptSetSpecSeqVanillaRep)
);

#ZeroCocycle@ := {arg...} -> 0;

InstallMethod(SptSetSpecSeqVanilla,
  "Construct a spectral sequence with a spectrum",
  [IsHapResolution, IsList],
  function(resolution, spectrum)
    return Objectify(TheTypeSptSetVanillaSpecSeq, rec(
      modulePages := [],
      derivPages := [],
      module2Pages := [],
      deriv2Pages := [],
      resolution := resolution,
      brMap := SptSetBarResolutionMap(resolution),
      spectrum := spectrum,
      bdry := [],
      addTwister := [],
      cochainTypes := [],
      classTypes := []));
  end);

InstallMethod(SptSetInstallCoboundary,
  "Install raw derivative of a spectral sequence",
  [IsSptSetSpecSeqVanillaRep, IsInt, IsInt, IsInt, IsFunction],
  function(ss, r, p, q, f)
    if not IsBound(ss!.bdry[r+1]) then
      ss!.bdry[r+1] := [];
    fi;
    if not IsBound(ss!.bdry[r+1][p+1]) then
      ss!.bdry[r+1][p+1] := [];
    fi;
    ss!.bdry[r+1][p+1][q+1] := f;
  end);

InstallMethod(SptSetInstallAddTwister,
  "Install add twister of a spectral sequence",
  [IsSptSetSpecSeqVanillaRep, IsInt, IsInt, IsFunction],
  function(ss, p, q, A)
      if not IsBound(ss!.addTwister[p+1]) then
          ss!.addTwister[p+1] := [];
      fi;
      ss!.addTwister[p+1][q+1] := A;
  end);

InstallMethod(SptSetSpecSeqBuildComponent,
  "build E^pq_r",
  [IsSptSetSpecSeqVanillaRep, IsInt, IsInt, IsInt],
  function(ss, r, p, q)
    local phi, psi;
    #if r=3 and p=1 and q=2 then
    #  Error("haha");
    #fi;
    if p < 0 or q < 0 then
      return SptSetZeroModule();
    fi;
    if not IsBound(ss!.spectrum[q+1]) then
      return SptSetZeroModule();
    fi;
    if r < 1 then
      Display("the spectral sequence starts at the first page");
      return fail;
    elif r = 1 then
      return SptSetCochainModule(ss!.resolution,
        p, ss!.spectrum[q+1]);
    else
      phi := SptSetSpecSeqDerivative(ss, r-1, p-(r-1), q+(r-1)-1);
#      psi := SptSetSpecSeqDerivative(ss, r-1, p, q);
      psi := SptSetSpecSeqDerivative2(ss, r-1, p, q);
      return SptSetHomologyModule(phi, psi);
    fi;
  end);

InstallMethod(SptSetSpecSeqBuildComponent2,
  "build tilde E^pq_r",
  [IsSptSetSpecSeqVanillaRep, IsInt, IsInt, IsInt],
  function(ss, r, p, q)
    local phi, psi;
    #if r=3 and p=1 and q=2 then
    #  Error("haha");
    #fi;
    if p < 0 or q < 0 then
      return SptSetZeroModule();
    fi;
    if not IsBound(ss!.spectrum[q+1]) then
      return SptSetZeroModule();
    fi;
    if r < 1 then
      Display("the spectral sequence starts at the first page");
      return fail;
    elif r = 1 then
      return SptSetCochainModule(ss!.resolution,
        p, ss!.spectrum[q+1]);
    else
      phi := SptSetSpecSeqDerivative2(ss, r-1, p-(r-1), q+(r-1)-1);
      return SptSetCokernelModule(phi);
    fi;
  end);

InstallMethod(SptSetSpecSeqBuildDerivative,
  "build d^pq_r",
  [IsSptSetSpecSeqVanillaRep, IsInt, IsInt, IsInt],
  function(ss, r, p, q)
    local M, N, m, n, fA, i, np_, dnp, cl_dnp, opr_, opr, saved_jobs, t_p2;
    M := SptSetSpecSeqComponent(ss, r, p, q);
    N := SptSetSpecSeqComponent(ss, r, p+r, q-r+1);
    if SptSetFpZModuleIsZero(M) or SptSetFpZModuleIsZero(N) then
      return SptSetZeroMap(M, N);
    fi;

    if r = 1 then
      return SptSetCoboundaryMap(M, N,
        ss!.resolution, p, ss!.spectrum[q+1]);
    fi;
    m := Length(M!.generators);
    n := Length(N!.generators);

    if not IsBound(ss!.derivPartial) then ss!.derivPartial := []; fi;
    if not IsBound(ss!.derivPartial[r+1]) then ss!.derivPartial[r+1] := []; fi;
    if not IsBound(ss!.derivPartial[r+1][p+1]) then ss!.derivPartial[r+1][p+1] := []; fi;
    if IsBound(ss!.derivPartial[r+1][p+1][q+1]) then
      fA := ss!.derivPartial[r+1][p+1][q+1];
    else
      fA := [];
    fi;

    if SPTSET_PARALLEL_JOBS > 0 and SPTSET_PHASE2_ENABLED
       and m >= 2 and IsBoundGlobal("ParListByFork") then
      saved_jobs := SPTSET_PARALLEL_JOBS;
      SPTSET_PARALLEL_JOBS := Maximum(0, Int(saved_jobs / m));
      t_p2 := NanosecondsSinceEpoch();

      fA := ParListByFork([1..m], function(idx)
        local lnp, ldnp, lcl, lopr_, lopr;
        lnp := SptSetMapToBarCocycle(ss!.brMap, p,
          ss!.spectrum[q+1], M!.generators[idx]);
        ldnp := SptSetSpecSeqCoboundarySL(ss, p+q, p, lnp);
        ldnp!.layers[p+1 +1] := ZeroCocycle@;
        lcl := SptSetSpecSeqClassFromCochainNC(ldnp);
        PartialPurifySSClass@(lcl, r, p+r-1);
        lopr_ := NegativeInhomoCochain@(lcl!.cochain!.layers[p+r +1]);
        lopr := SptSetMapFromBarCocycle(ss!.brMap,
          p+r, ss!.spectrum[q-r+1 +1], lopr_);
        return lopr * N!.projection;
      end, rec(NumberJobs := Minimum(m, saved_jobs)));

      SPTSET_PARALLEL_JOBS := saved_jobs;
      SPTSET_STATS.p2_calls := SPTSET_STATS.p2_calls + 1;
      SPTSET_STATS.p2_time := SPTSET_STATS.p2_time
        + Int((NanosecondsSinceEpoch()-t_p2)/1000000);
      if m > SPTSET_STATS.p2_max_m then SPTSET_STATS.p2_max_m := m; fi;
      if SPTSET_CHECKPOINT_HOOK <> false then
        Print("    d^{", p, ",", q, "}_", r,
          " all ", m, " gens done (parallel), saving...\n");
        SPTSET_CHECKPOINT_HOOK();
      fi;
    else
      for i in [1..m] do
        if not IsBound(fA[i]) then
          if SPTSET_CHECKPOINT_HOOK <> false then
            Print("    d^{", p, ",", q, "}_", r,
              " gen ", i, "/", m, "...\n");
          fi;
          np_ := SptSetMapToBarCocycle(ss!.brMap, p,
            ss!.spectrum[q+1], M!.generators[i]);
          dnp := SptSetSpecSeqCoboundarySL(ss, p+q, p, np_);
          dnp!.layers[p+1 +1] := ZeroCocycle@;
          cl_dnp := SptSetSpecSeqClassFromCochainNC(dnp);
          PartialPurifySSClass@(cl_dnp, r, p+r-1);
          Assert(-1, LeadingLayer(cl_dnp) = p+r-1,
            "ASSERTION FAIL: obstruction does not vanish on the previous page.");
          opr_ := NegativeInhomoCochain@(cl_dnp!.cochain!.layers[p+r +1]);
          opr := SptSetMapFromBarCocycle(ss!.brMap,
            p+r, ss!.spectrum[q-r+1 +1], opr_);
          fA[i] := opr * N!.projection;
          if SPTSET_CHECKPOINT_HOOK <> false then
            ss!.derivPartial[r+1][p+1][q+1] := fA;
            SPTSET_CHECKPOINT_HOOK();
          fi;
        fi;
      od;
    fi;

    if IsBound(ss!.derivPartial[r+1][p+1][q+1]) then
      Unbind(ss!.derivPartial[r+1][p+1][q+1]);
    fi;

    return SptSetZLMapByImages(M, N, fA);

  end);

InstallMethod(SptSetSpecSeqBuildDerivative2,
  "build d^pq_r",
  [IsSptSetSpecSeqVanillaRep, IsInt, IsInt, IsInt],
  function(ss, r, p, q)
    local M, N, m, n, fA, i, np_, dnp, cl_dnp, opr_, opr, saved_jobs, t_p2;
    M := SptSetSpecSeqComponent(ss, r, p, q);
    N := SptSetSpecSeqComponent2(ss, r, p+r, q-r+1);
    if SptSetFpZModuleIsZero(M) or SptSetFpZModuleIsZero(N) then
      return SptSetZeroMap(M, N);
    fi;

    if r = 1 then
      return SptSetCoboundaryMap(M, N,
        ss!.resolution, p, ss!.spectrum[q+1]);
    fi;
    m := Length(M!.generators);
    n := Length(N!.generators);

    if not IsBound(ss!.deriv2Partial) then ss!.deriv2Partial := []; fi;
    if not IsBound(ss!.deriv2Partial[r+1]) then ss!.deriv2Partial[r+1] := []; fi;
    if not IsBound(ss!.deriv2Partial[r+1][p+1]) then ss!.deriv2Partial[r+1][p+1] := []; fi;
    if IsBound(ss!.deriv2Partial[r+1][p+1][q+1]) then
      fA := ss!.deriv2Partial[r+1][p+1][q+1];
    else
      fA := [];
    fi;

    if SPTSET_PARALLEL_JOBS > 0 and SPTSET_PHASE2_ENABLED
       and m >= 2 and IsBoundGlobal("ParListByFork") then
      saved_jobs := SPTSET_PARALLEL_JOBS;
      SPTSET_PARALLEL_JOBS := Maximum(0, Int(saved_jobs / m));
      t_p2 := NanosecondsSinceEpoch();

      fA := ParListByFork([1..m], function(idx)
        local lnp, ldnp, lcl, lopr_, lopr;
        lnp := SptSetMapToBarCocycle(ss!.brMap, p,
          ss!.spectrum[q+1], M!.generators[idx]);
        ldnp := SptSetSpecSeqCoboundarySL(ss, p+q, p, lnp);
        ldnp!.layers[p+1 +1] := ZeroCocycle@;
        lcl := SptSetSpecSeqClassFromCochainNC(ldnp);
        PartialPurifySSClass@(lcl, r, p+r-1);
        lopr_ := NegativeInhomoCochain@(lcl!.cochain!.layers[p+r +1]);
        lopr := SptSetMapFromBarCocycle(ss!.brMap,
          p+r, ss!.spectrum[q-r+1 +1], lopr_);
        return lopr * N!.projection;
      end, rec(NumberJobs := Minimum(m, saved_jobs)));

      SPTSET_PARALLEL_JOBS := saved_jobs;
      SPTSET_STATS.p2_calls := SPTSET_STATS.p2_calls + 1;
      SPTSET_STATS.p2_time := SPTSET_STATS.p2_time
        + Int((NanosecondsSinceEpoch()-t_p2)/1000000);
      if m > SPTSET_STATS.p2_max_m then SPTSET_STATS.p2_max_m := m; fi;
      if SPTSET_CHECKPOINT_HOOK <> false then
        Print("    d2^{", p, ",", q, "}_", r,
          " all ", m, " gens done (parallel), saving...\n");
        SPTSET_CHECKPOINT_HOOK();
      fi;
    else
      for i in [1..m] do
        if not IsBound(fA[i]) then
          if SPTSET_CHECKPOINT_HOOK <> false then
            Print("    d2^{", p, ",", q, "}_", r,
              " gen ", i, "/", m, "...\n");
          fi;
          np_ := SptSetMapToBarCocycle(ss!.brMap, p,
            ss!.spectrum[q+1], M!.generators[i]);
          dnp := SptSetSpecSeqCoboundarySL(ss, p+q, p, np_);
          dnp!.layers[p+1 +1] := ZeroCocycle@;
          cl_dnp := SptSetSpecSeqClassFromCochainNC(dnp);
          PartialPurifySSClass@(cl_dnp, r, p+r-1);
          Assert(-1, LeadingLayer(cl_dnp) = p+r-1,
            "ASSERTION FAIL: obstruction does not vanish on the previous page.");
          opr_ := NegativeInhomoCochain@(cl_dnp!.cochain!.layers[p+r +1]);
          opr := SptSetMapFromBarCocycle(ss!.brMap,
            p+r, ss!.spectrum[q-r+1 +1], opr_);
          fA[i] := opr * N!.projection;
          if SPTSET_CHECKPOINT_HOOK <> false then
            ss!.deriv2Partial[r+1][p+1][q+1] := fA;
            SPTSET_CHECKPOINT_HOOK();
          fi;
        fi;
      od;
    fi;

    if IsBound(ss!.deriv2Partial[r+1][p+1][q+1]) then
      Unbind(ss!.deriv2Partial[r+1][p+1][q+1]);
    fi;

    return SptSetZLMapByImages(M, N, fA);

  end);


InstallGlobalFunction(SptSetSpecSeqCochainType,
function(ss, deg)
  local f;
  if not IsBound(ss!.cochainTypes[deg+1]) then
    f := NewFamily("SptSetSSCochainFamily");
    f!.specSeq := ss;
    f!.degree := deg;
    ss!.cochainTypes[deg+1] := NewType(f, IsSptSetSpecSeqCochainRep);
  fi;
  return ss!.cochainTypes[deg+1];
end);

InstallGlobalFunction(SptSetSpecSeqClassType,
function(ss, deg)
  local f;
  if not IsBound(ss!.classTypes[deg+1]) then
    f := NewFamily("SptSetSSClassFamily");
    f!.specSeq := ss;
    f!.degree := deg;
    ss!.classTypes[deg+1] := NewType(f, IsSptSetSpecSeqClassRep);
  fi;
  return ss!.classTypes[deg+1];
end);
