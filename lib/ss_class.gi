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

    # If the class at layer p could not be killed by any differential or as a
    # coboundary (a genuine obstruction), stop: the leading layer is p.
    cp_ := coc!.layers[p+1];
    if cp_ <> ZeroCocycle@ then
      cp := SptSetMapFromBarCocycle(brMap, p, SS!.spectrum[q+1], cp_);
      if not SptSetFpZModuleIsZeroElm(
          SptSetSpecSeqComponent(SS, 2, p, q), cp) then
        break;
      fi;
    fi;

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
    # Only kill when cp is genuinely in the image of d_r (integral solution).
    # If cp is not in the image, it is a genuine obstruction on this page;
    # do NOT attempt a kill (a pseudo-inverse would return a fractional or
    # spurious beta and contaminate the whole cochain).
    beta := SptSetZLMapInImage(dr, cp);
    if beta = fail then
      if SPTSET_DEBUG_PURIFY then
        Print(">> PartialPurify(deg=", deg, ",p=", p, ",r=", r,
              "): cp NOT in image of d_", r, " - genuine obstruction, no kill\n");
      fi;
      return SptSetSpecSeqCochainZero(SS, deg-1);
    fi;
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
  cp_, n, n_, bdry, dnc, _pp, _chk;
  F := FamilyObj(coc);
  SS := F!.specSeq;
  deg := F!.degree;
  brMap := SS!.brMap;
  q := deg - p;

  bdry := SptSetSpecSeqCochainZero(SS, deg-1);
  cp_ := coc!.layers[p+1];
  # cp_ must be a trivial coboundary.  Verify integrally; if cp is not a
  # genuine coboundary, it is a genuine obstruction -- do NOT kill.
  n := SptSetZLMapInImage(SptSetSpecSeqDerivative(SS, 1, p-1, q), cp);
  if n = fail then
    if SPTSET_DEBUG_PURIFY then
      Print(">> PurifyCobdry(deg=", deg, ",p=", p, ",q=", q,
            "): cp not a coboundary - genuine obstruction, no kill\n");
    fi;
    return SptSetSpecSeqCochainZero(SS, deg-1);
  fi;
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
