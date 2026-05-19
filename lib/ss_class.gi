DeclareRepresentation(
"IsSptSetSpecSeqClassRep",
IsCategoryOfSptSetSpecSeqClass and IsComponentObjectRep and IsAttributeStoringRep,
["cochain"]
);

InstallGlobalFunction(SptSetSpecSeqClassFromCochainNC,
function(c)
  local cl, Fc, SS, deg, Tcl;

  Fc := FamilyObj(c);
  SS := Fc!.specSeq;
  deg := Fc!.degree;
  Tcl := SptSetSpecSeqClassType(SS, deg);
  return Objectify(Tcl, rec(cochain := c));
end);

InstallMethod(\+,
"add two classes",
IsIdenticalObj,
[IsSptSetSpecSeqClassRep, IsSptSetSpecSeqClassRep],
function(cl1, cl2)
  local c1, c2, c3;
  c1 := cl1!.cochain;
  c2 := cl2!.cochain;
  c3 := SptSetStack(c1, c2);
  return SptSetSpecSeqClassFromCochainNC(c3);
end);

InstallMethod
    (AdditiveInverseMutable,
     "Inverse of a SpecSeq class",
     [IsSptSetSpecSeqClassRep],
     function(cl)
         local cochain;
         cochain := SptSetInverse(cl!.cochain);
         return SptSetSpecSeqClassFromCochainNC(cochain);
     end);

InstallMethod(ZeroMutable,
"Zero SpecSeq class",
[IsSptSetSpecSeqClassRep],
function(cl)
  local F, SS, deg;
  F := FamilyObj(cl);
  SS := F!.specSeq;
  deg := F!.degree;
  return SptSetSpecSeqClassFromCochainNC(SptSetSpecSeqCochainZero(SS, deg));
end);

InstallGlobalFunction(SptSetPurifySpecSeqClass,
function(cl) # recursive version
  local F, SS, deg, coc, brMap, bdry, bdry2, p, q, cp, cp_, Epqinf, r, Erpq;

  F := FamilyObj(cl);
  SS := F!.specSeq;
  deg := F!.degree;
  coc := cl!.cochain;
  brMap := SS!.brMap;

  bdry := SptSetSpecSeqCochainZero(SS, deg-1);

  for p in [0..deg] do
    #if p = deg then
      #Display("Last layer does not need tobe purified.");
      #break;
    #fi;
    if coc!.layers[p+1] = ZeroCocycle@ then
      continue;
    fi;
    q := deg - p;
    cp_ := coc!.layers[p+1];
    cp := SptSetMapFromBarCocycle(brMap, p, SS!.spectrum[q+1], cp_);
    if not ForAll(cp, IsInt) then
      Print("!! DIAG PurifyClass(deg=", deg, ",p=", p,
            "): top layer NOT integer, frac indices=",
            Filtered([1..Length(cp)], i -> not IsInt(cp[i])),
            " values=", Filtered(cp, x -> not IsInt(x)), "\n");
    fi;

    Epqinf := SptSetSpecSeqComponentInf(SS, p, q);
    if not SptSetFpZModuleIsZeroElm(Epqinf, cp) then
      break;
    fi;

    #Assert(0, SptSetFpZModuleIsZeroElm(
    #SptSetSpecSeqComponent2(SS, p+1, p, q), cp),
    #"Assertion: p+1 should be the highest page with trivialization");
    for r in [p,(p-1)..2] do
      Erpq := SptSetSpecSeqComponent(SS, r, p, q);
      if not SptSetFpZModuleIsZeroElm(Erpq, cp) then
        bdry2 := PartialPurify@(coc, p, r, cp);
        SptSetStackInplace(bdry, bdry2);
        cp_ := coc!.layers[p+1];
        cp := SptSetMapFromBarCocycle(brMap, p, SS!.spectrum[q+1], cp_);
      fi;
    od;

    bdry2 := PartialPurifyCoboundary@(coc, p, cp);
    SptSetStackInplace(bdry, bdry2);
    # bdry!.layers[p-1+1] := bdry2!.layers[p-1+1];

  od;

  cl!.cochain := coc;
  SetLeadingLayer(cl, p);

  return bdry;
end);

InstallGlobalFunction(PartialPurify@,
function(coc, p, r, cp)
    local F, SS, deg, brMap, q,
          dr, beta, beta_, bdry, dbeta, _pp, _chk;
    F := FamilyObj(coc);
    SS := F!.specSeq;
    deg := F!.degree;
    brMap := SS!.brMap;
    q := deg - p;

    dr := SptSetSpecSeqDerivative(SS, r, p-r, q+r-1);
    if IsSptSetZLMapZeroRep(dr) then
      return SptSetSpecSeqCochainZero(SS, deg-1);
    fi;
    # ---- DIAG: print BEFORE calling ZLMapInverse ----
    Print("  > PartialPurify r=", r, " p=", p, " q=", q,
          " cp_len=", Length(cp),
          " cp=", cp, "\n");
    beta := SptSetZLMapInverse(dr, cp);
    beta_ := SptSetMapToBarCocycle(brMap, p-r, SS!.spectrum[q+r-1 +1], beta);

    dbeta := SptSetSpecSeqCoboundarySL(SS, deg-1, p-r, NegativeInhomoCochain@(beta_));
    dbeta!.layers[p-r+1+1] := ZeroCocycle@;
    SptSetStackInplace(coc, dbeta);

    for _pp in [(p+1)..deg] do
      if coc!.layers[_pp+1] <> ZeroCocycle@ and
         not IsSptSetCoeffU1Rep(SS!.spectrum[deg-_pp+1]) then
        _chk := SptSetMapFromBarCocycle(brMap, _pp,
          SS!.spectrum[deg-_pp+1], coc!.layers[_pp+1]);
        if not ForAll(_chk, IsInt) then
          Print("!! DIAG PartialPurify(deg=",deg,",p=",p,",r=",r,
                "): after stack, layer ",_pp," FRAC\n");
          break;
        fi;
      fi;
    od;

    bdry := SptSetSpecSeqCochainZero(SS, deg-1);
    bdry!.layers[p-r+1] := NegativeInhomoCochain@(beta_);
    return bdry;
end);

InstallGlobalFunction(PartialPurifyCoboundary@,
function(coc, p, cp)
  local F, SS, deg, brMap, q,
  cp_, n, n_, bdry, dnc, _pp, _chk, _psi, _psi_mat, _cp_psi,
  _bw, _val, _j;
  F := FamilyObj(coc);
  SS := F!.specSeq;
  deg := F!.degree;
  brMap := SS!.brMap;
  q := deg - p;

  bdry := SptSetSpecSeqCochainZero(SS, deg-1);
  cp_ := coc!.layers[p+1];
  # cp_ must be a trivial coboundary.
  Print("  > PurifyCobdry p=", p, " q=", q, " cp_len=", Length(cp),
        " cp=", cp, "\n");
  # DIAG: directly sample the cochain function on a few bar basis elements
  Print("    DIAG direct cochain sample (first 5 bar words):\n");
  for _ii in [1..Minimum(5, Length(cp))] do
    _bw := SptSetMapToBarWord(brMap, p, _ii);;
    _val := 0;;
    for _j in [1..Length(_bw)] do
      _val := _val + _bw[_j][1] * (_bw[_j][2]^(SS!.spectrum[q+1]!.gAction))[1][1]
        * CallFuncList(cp_, _bw[_j]{[3..(p+2)]});
    od;
    Print("      bar[", _ii, "]=", _val, " vs cp[", _ii, "]=", cp[_ii], "\n");
  od;
  # DIAG: check psi = d_1^{p,q} matrix directly
  _psi := SptSetSpecSeqDerivative(SS, 1, p, q);;
  if not IsSptSetZLMapZeroRep(_psi) and IsBound(_psi!.B) then
    Print("    DIAG psi.B dims=", DimensionsMat(_psi!.B), "\n");
    Print("    DIAG psi.domain gens_dims=", DimensionsMat(_psi!.domain!.generators),
          " proj_dims=", DimensionsMat(_psi!.domain!.projection), "\n");
    Print("    DIAG psi.codomain gens_dims=", DimensionsMat(_psi!.codomain!.generators),
          " proj_dims=", DimensionsMat(_psi!.codomain!.projection), "\n");
    _psi_mat := _psi!.domain!.generators * _psi!.B * _psi!.codomain!.projection;;
    _cp_psi := cp * _psi_mat;;
    Print("    DIAG cp*_psi_mat len=", Length(_cp_psi),
          " allZero=", ForAll(_cp_psi, x->x=0),
          " firstNonzero=", Filtered(_cp_psi, x->x<>0), "\n");
    # Also try: cp directly on psi.B (raw bar basis coboundary)
    _cp_psi_raw := cp * _psi!.B;;
    Print("    DIAG cp*psi.B (raw bar) len=", Length(_cp_psi_raw),
          " allZero=", ForAll(_cp_psi_raw, x->x=0),
          " firstNonzero=", Filtered(_cp_psi_raw, x->x<>0), "\n");
  fi;
  n := SptSetZLMapInverse(SptSetSpecSeqDerivative(SS, 1, p-1, q), cp);
  n_ := SptSetSolveCocycleEq(brMap, p, SS!.spectrum[q+1], cp_, n);
  # n_ := NegativeInhomoCochain@(n_);
  # bdry!.layers[p-1 +1] := n_;
  
  bdry!.layers[p-1 +1] := NegativeInhomoCochain@(n_);
  # bdry!.layers[p-1 +1] := n_;

  dnc := SptSetSpecSeqCoboundarySL(SS, deg-1, p-1, NegativeInhomoCochain@(n_));
  SptSetStackInplace(coc, dnc);
  coc!.layers[p+1] := ZeroCocycle@;

  for _pp in [(p+1)..deg] do
    if coc!.layers[_pp+1] <> ZeroCocycle@ and
       not IsSptSetCoeffU1Rep(SS!.spectrum[deg-_pp+1]) then
      _chk := SptSetMapFromBarCocycle(brMap, _pp,
        SS!.spectrum[deg-_pp+1], coc!.layers[_pp+1]);
      if not ForAll(_chk, IsInt) then
        Print("!! DIAG PurifyCobdry(deg=",deg,",p=",p,
              "): after stack, layer ",_pp," FRAC\n");
        break;
      fi;
    fi;
  od;

  return bdry;
end);

InstallGlobalFunction(SptSetSpecSeqClassFromLevelCocycle,
function(SS, deg, p, a)
  local brMap, q, a_, da, cl_da, b;
  brMap := SS!.brMap;
  q := deg - p;
  a_ := SptSetMapToBarCocycle(brMap, p, SS!.spectrum[q+1], a);
  da := SptSetSpecSeqCoboundarySL(SS, deg, p, a_);
  da!.layers[p+1 +1] := ZeroCocycle@; # da must be a cocycle.
  cl_da := SptSetSpecSeqClassFromCochainNC(da);
  b := SptSetPurifySpecSeqClass(cl_da);
  b!.layers[p+1] := a_;
  #return b;
  return SptSetSpecSeqClassFromCochainNC(b);
end);
