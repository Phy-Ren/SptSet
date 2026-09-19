BindGlobal(
  "TheFamilyOfSptSetBarResMaps",
  NewFamily("TheFamilyOfSptSetBarResMaps")
);

#############################################################################
##
#F  SptSetParListByForkSafe( <list>, <map>, <opt> )
##
##  Fork-parallel  List(<list>, <map>)  with robust error handling.
##
##  Guards against two failure modes of the IO package's `ParListByFork`:
##
##  (1) A worker that dies without delivering its pickled result (OOM kill,
##      GAP error inside the worker, ...) makes `WaitUntilIdle` store `fail`
##      in the result list.  `fail` is *bound*, so the original completeness
##      test (IsBound only) passed and the final `Concatenation(res)`
##      aborted the whole session with the misleading error
##      "Concatenation: arguments must be lists".
##      -> fixed together with a local one-line patch in
##         pkg/io/gap/background.gi (ParListByFork), which now returns `fail`
##         instead of crashing on such a result list.
##  (2) Workers used to inherit a positive `SPTSET_PARALLEL_JOBS` and could
##      fork grandchildren themselves: memory blow-up (children get
##      OOM-killed silently) plus redundant nested recomputation.
##
##  Strategy:
##  * worker side: set `SPTSET_PARALLEL_JOBS := 0` inside the worker
##    (one process copy per worker, no nested forks).
##  * parent side: if `ParListByFork` returns `fail` (dead worker, timeout)
##    or a malformed result, fall back to a plain sequential
##    `List(<list>, <map>)`, so the batch finishes and any real error
##    surfaces cleanly in the parent process.
##
##  NOTE (verified 2026-09): ordinary GAP errors are NOT catchable in this
##  GAP build -- `CALL_WITH_CATCH` only intercepts kernel `GAP_THROW`, not
##  break-loop errors (even a plain `Error()` escapes it).  A worker
##  therefore cannot rescue its own failing `map`; the parent-side fallback
##  is what provides the robustness.
##
BindGlobal("SptSetParListByForkSafe", function(l, map, opt)
  local worker, res;

  if Length(l) = 0 then
    return [];
  fi;
  if not IsBoundGlobal("ParListByFork") then
    return List(l, map);
  fi;

  worker := function(x)
    local saved, val;
    saved := SPTSET_PARALLEL_JOBS;
    SPTSET_PARALLEL_JOBS := 0;   # no nested forks inside a worker
    val := map(x);
    SPTSET_PARALLEL_JOBS := saved;
    return val;
  end;

  res := ParListByFork(l, worker, opt);
  if res = fail or not IsList(res) or Length(res) <> Length(l) then
    Print("#W  SptSet[parallel]: ParListByFork failed ",
          "(worker died? e.g. OOM-killed); ",
          "falling back to sequential computation.\n");
    return List(l, map);
  fi;

  return res;
end);

InstallMethod(SptSetMapToBarCocycle,
"map to an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsGeneralMapping, IsRowVector],
function(brMap, deg, gAction, alpha)
  local f;
  f := function(glist...)
    local elts, w, x, val, xs, xg, xb;
    if Length(glist) <> deg then
      return fail;
    fi;
    elts := brMap!.hapResolution!.elts;
    w := SptSetMapFromBarWord(brMap, deg, glist);
    val := 0;
    for x in w do
      xs := x[1];
      xb := x[2];
      xg := elts[x[3]];
      val := val + xs * (xg^gAction)[1][1] * alpha[xb];
    od;

    return val;
  end;
  return f;
end);

InstallMethod(SptSetMapToBarCocycle,
"map to an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsSptSetCoeffZnRep, IsRowVector],
function(brMap, deg, coeff, alpha)
  return SptSetMapToBarCocycle(brMap, deg, coeff!.gAction, alpha);
end);

InstallMethod(SptSetMapToBarCocycle,
              "map to an inhomogeneous cocycle",
              [IsCategoryOfSptSetBarResMap, IsInt, IsSptSetCoeffU1Rep, IsRowVector],
              function(brmap, deg, coeff, alpha)
                  local beta;
                  beta := SolveU1CocycleEq@(brmap!.hapResolution, deg+1, coeff!.gAction, alpha);
                  return SptSetMapToBarCocycle(brmap, deg, coeff!.gAction, beta);
              end);

InstallMethod(SptSetMapFromBarCocycle,
"map from an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsGeneralMapping, IsFunction],
function(brMap, deg, gAction, alpha_)
  local n, val, i, fei, feiw, nJobs, t_start;
  n := Dimension(brMap!.hapResolution)(deg);

  nJobs := SPTSET_PARALLEL_JOBS;
  if nJobs > 0 and n >= SPTSET_PARALLEL_THRESHOLD
     and IsBoundGlobal("ParListByFork") then
    t_start := NanosecondsSinceEpoch();
    for i in [1..n] do
      SptSetMapToBarWord(brMap, deg, i);
    od;

    val := SptSetParListByForkSafe([1..n], function(idx)
      local v, bar, w;
      v := 0;
      bar := SptSetMapToBarWord(brMap, deg, idx);
      for w in bar do
        v := v + w[1] * (w[2]^gAction)[1][1]
          * CallFuncList(alpha_, w{[3..(deg+2)]});
      od;
      return v;
    end, rec(NumberJobs := Minimum(nJobs, n)));
    SPTSET_STATS.p1_par_calls := SPTSET_STATS.p1_par_calls + 1;
    SPTSET_STATS.p1_par_time := SPTSET_STATS.p1_par_time
      + Int((NanosecondsSinceEpoch()-t_start)/1000000);
  else
    t_start := NanosecondsSinceEpoch();
    val := [];
    for i in [1..n] do
      val[i] := 0;
      fei := SptSetMapToBarWord(brMap, deg, i);
      for feiw in fei do
        val[i] := val[i] + feiw[1] * (feiw[2]^gAction)[1][1]
          * CallFuncList(alpha_, feiw{[3..(deg+2)]});
      od;
    od;
    SPTSET_STATS.p1_seq_calls := SPTSET_STATS.p1_seq_calls + 1;
    SPTSET_STATS.p1_seq_time := SPTSET_STATS.p1_seq_time
      + Int((NanosecondsSinceEpoch()-t_start)/1000000);
  fi;
  return val;
end);
InstallMethod(SptSetMapFromBarCocycle,
"map from an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsSptSetCoeffZnRep, IsFunction],
function(brMap, deg, coeff, alpha_)
  return SptSetMapFromBarCocycle(brMap, deg, coeff!.gAction, alpha_);
end);
InstallMethod(SptSetMapFromBarCocycle,
"map from an inhomogeneous cocycle",
[IsCategoryOfSptSetBarResMap, IsInt, IsSptSetCoeffU1Rep, IsFunction],
function(brMap, deg, coeff, alpha_)
  local alpha;
  alpha := SptSetMapFromBarCocycle(brMap, deg, coeff!.gAction, alpha_);
  return SptSetBockstein(brMap!.hapResolution,
    deg, coeff!.gAction, alpha);
end);

InstallMethod(SptSetSolveCocycleEq,
"solve an inhomogeneous cocycle equation using maps to/from the bar resolution",
[IsCategoryOfSptSetBarResMap, IsInt, IsGeneralMapping,
  IsFunction, IsRowVector],
function(brMap, deg, gAction, alpha_, beta)
  local solveCocycleEq, alpha, h_alpha_, beta_;
  beta_ := SptSetMapToBarCocycle(brMap, deg-1, gAction, beta);
  h_alpha_ := function(glist...)
    local w, hw, whw, val;
    #w := [1, Identity(brMap!.group)];
    #Append(w, glist);
    #hw := StructuralCopy(brMap!.hapEquiv!.equiv(deg-1, [w]));
    hw := StructuralCopy(SptSetMapEquivBarWord(brMap, glist));
    val := 0;
    for whw in hw do
      val := val + whw[1] * (whw[2]^gAction)[1][1]
        * CallFuncList(alpha_, whw{[3..(deg+2)]});
    od;
    return val;
  end;

  return function(glist...)
    return CallFuncList(beta_, glist) - CallFuncList(h_alpha_, glist);
  end;
end);
InstallMethod(SptSetSolveCocycleEq,
"solve an inhomogeneous cocycle equation using maps to/from the bar resolution",
[IsCategoryOfSptSetBarResMap, IsInt, IsSptSetCoeffZnRep,
  IsFunction, IsRowVector],
function(brMap, deg, coeff, alpha_, beta)
  return SptSetSolveCocycleEq(brMap, deg, coeff!.gAction, alpha_, beta);
end);

InstallGlobalFunction(SolveU1CocycleEq@,
function(hapResolution, deg, f, a)
  local bdry, G, elts, nd, ndm1, cobdryMat, j, dej, wdej, sw, iw, gw,
        snf, U, V, D, i, a2, b, cobdryMat1;
  bdry := BoundaryMap(hapResolution);
  G := GroupOfResolution(hapResolution);
  elts := hapResolution!.elts;

  nd := Dimension(hapResolution)(deg);
  ndm1 := Dimension(hapResolution)(deg - 1);
  cobdryMat := NullMat(ndm1, nd);
  for j in [1..nd] do
    dej := bdry(deg, j);
    for wdej in dej do
      sw := SignInt(wdej[1]);
      iw := AbsInt(wdej[1]);
      gw := elts[wdej[2]];
      cobdryMat[iw][j] := cobdryMat[iw][j] + sw * ((gw^f)[1][1]);
    od;
  od;

  snf := SmithNormalFormIntegerMatTransforms(cobdryMat);
  U := snf.rowtrans;
  D := snf.normal;
  V := snf.coltrans;
  a2 := a * V;
  b := [];

  for i in [1..ndm1] do
    if IsBound(D[i][i]) and D[i][i] <> 0 then
      b[i] := a2[i] / D[i][i];
    else
        Assert(0, a2[i] = 0, "a is not a coboundary");


      #if a2[i] <> 0 then
        #Error("a is not a coboundary");
      #fi;
      b[i] := 0;
    fi;
  od;
  b := b * U;
  return b;
end);

InstallMethod(SptSetSolveCocycleEq,
"solve an inhomogeneous cocycle equation: spectial U(1) edition",
[IsCategoryOfSptSetBarResMap, IsInt, IsSptSetCoeffU1Rep,
  IsFunction, IsRowVector],
function(brMap, deg, coeff, alpha_, beta)
  local res, alpha, alpha2, beta2;
  res := brMap!.hapResolution;
  alpha := SptSetMapFromBarCocycle(brMap, deg, coeff!.gAction, alpha_);
  alpha2 := alpha - beta;
  beta2 := SolveU1CocycleEq@(res, deg, coeff!.gAction, alpha2);
  return SptSetSolveCocycleEq(brMap, deg, coeff!.gAction, alpha_, beta2);
end);
