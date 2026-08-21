DeclareRepresentation(
"IsSptSetSpecSeqCochainRep",
IsCategoryOfSptSetSpecSeqCochain and IsComponentObjectRep,
["layers"]
);

InstallGlobalFunction(SptSetSpecSeqCochain,
function(ss, deg, layers)
  local t;
  t := SptSetSpecSeqCochainType(ss, deg);
  return Objectify(t, rec(layers := layers));
end);

InstallGlobalFunction(SptSetSpecSeqCochainZero,
function(ss, deg)
  local layers, p;
  layers := [];
  for p in [0..deg] do
    layers[p+1] := ZeroCocycle@;
  od;
  return SptSetSpecSeqCochain(ss, deg, layers);
end);

InstallMethod(SptSetStack,
"stack two cochains",
IsIdenticalObj,
[IsSptSetSpecSeqCochainRep, IsSptSetSpecSeqCochainRep],
function(c1, c2)
  local F, SS, deg, p, layers, q;
  F := FamilyObj(c1);
  SS := F!.specSeq;
  deg := F!.degree;
  layers := [];
  for p in [0..deg] do
    q := deg - p;
    layers[p+1] := AddInhomoCochain@(c1!.layers[p+1], c2!.layers[p+1]);
    if p > 0 then # the p=0 layer cannot be twisted
      if IsBound(SS!.addTwister[p+1]) and IsBound(SS!.addTwister[p+1][q+1]) then
        layers[p+1] := AddInhomoCochain@(layers[p+1],
        SS!.addTwister[p+1][q+1](c1!.layers, c2!.layers));
      fi;
    fi;
  od;

  return SptSetSpecSeqCochain(SS, deg, layers);
end);

InstallMethod(SptSetStackInplace,
"stack the second cochain to the first",
IsIdenticalObj,
[IsSptSetSpecSeqCochainRep, IsSptSetSpecSeqCochainRep],
function(c1, c2)
  local F, SS, deg, p, layers, q;
  F := FamilyObj(c1);
  SS := F!.specSeq;
  deg := F!.degree;
  layers := [];
  for p in [0..deg] do
    q := deg - p;
    layers[p+1] := AddInhomoCochain@(c1!.layers[p+1], c2!.layers[p+1]);
    if p > 0 then # the p=0 layer cannot be twisted
      if IsBound(SS!.addTwister[p+1]) and IsBound(SS!.addTwister[p+1][q+1]) then
        layers[p+1] := AddInhomoCochain@(layers[p+1],
        SS!.addTwister[p+1][q+1](c1!.layers, c2!.layers));
      fi;
    fi;
  od;

  c1!.layers := layers;
end);

InstallMethod
    (SptSetInverse,
     "Compute the inverse of cochains",
     [IsSptSetSpecSeqCochainRep],
     function(c)
         local F, SS, deg, layers, p, p1, dcp1;
         F := FamilyObj(c);
         SS := F!.specSeq;
         deg := F!.degree;
         layers := [];

         for p in [0..deg] do
             if c!.layers[p+1] = ZeroCocycle@ then
                 layers[p+1] := ZeroCocycle@ ;
             else
                 break;
             fi;
         od;

         for p1 in [p..deg] do
             layers[p1+1] := NegativeInhomoCochain@(c!.layers[p1+1]);
             dcp1 := SS!.addTwister[p1 +1][(deg - p1) +1](c!.layers, layers);
             layers[p1+1] := AddInhomoCochain@(layers[p1+1], NegativeInhomoCochain@(dcp1));
         od;
         return SptSetSpecSeqCochain(SS, deg, layers);
     end);
              

InstallGlobalFunction(SptSetSpecSeqCoboundarySL,
function(SS, deg, p, a)
  local gid, q, dalayers, da, rmax, r, pp;
  gid := Identity(GroupOfResolution(SS!.resolution));
  q := deg - p;
  dalayers := [];
  da := InhomoCoboundary@(SS!.spectrum[q+1], a);
  for pp in [0..p] do
    dalayers[pp+1] := ZeroCocycle@;
  od;
  dalayers[(p+1)+1] := da;
  rmax := q + 1;
  for r in [2..rmax] do
    if IsBound(SS!.bdry[r+1]) and IsBound(SS!.bdry[r+1][p+1])
       and IsBound(SS!.bdry[r+1][p+1][q+1]) then
      dalayers[p + r +1] := NegativeInhomoCochain@(SS!.bdry[r+1][p+1][q+1](a, da));
    else
      dalayers[p + r +1] := ZeroCocycle@;
    fi;
  od;
  return SptSetSpecSeqCochain(SS, deg+1, dalayers);
end);

InstallGlobalFunction(SptSetSpecSeqCoboundary,
function(c)
  local F, SS, deg, p, dcp, dc;
  F := FamilyObj(c);
  SS := F!.specSeq;
  deg := F!.degree;

  dc := SptSetSpecSeqCochainZero(SS, deg);

  for p in [0..deg] do
    if c!.layers[p+1] <> ZeroCocycle@ then
      dcp := SptSetSpecSeqCoboundarySL(SS, deg, p, c!.layers[p+1]);
      dc := SptSetStack(dc, dcp);
    fi;
  od;

  return dc;
end);

InstallGlobalFunction(PartialPurifySSClass@,
function(cl, rf, pf)
  # pf = last layer to be purified.
  # rf = highest page available.
  local F, SS, deg, coc, brMap, bdry, bdry2, p, q, cp, cp_, Epqrf, r, Erpq;

  F := FamilyObj(cl);
  SS := F!.specSeq;
  deg := F!.degree;
  coc := cl!.cochain;
  brMap := SS!.brMap;

  bdry := SptSetSpecSeqCochainZero(SS, deg-1);

  Assert(0, pf <= deg);

  for p in [0..pf] do
    if coc!.layers[p+1] = ZeroCocycle@ then
      continue;
    fi;
    q := deg - p;
    cp_ := coc!.layers[p+1];
    cp := SptSetMapFromBarCocycle(brMap, p, SS!.spectrum[q+1], cp_);
    if not ForAll(cp, IsInt) then
      Print("!! DIAG PartialPurifySSClass(deg=", deg, ",p=", p,
            ",rf=", rf, "): top layer NOT integer, frac indices=",
            Filtered([1..Length(cp)], i -> not IsInt(cp[i])),
            " values=", Filtered(cp, x -> not IsInt(x)), "\n");
    fi;

    if rf > 0 then
      Epqrf := SptSetSpecSeqComponent(SS, rf, p, q);
    else
      Epqrf := SptSetSpecSeqComponentInf(SS, p, q);
    fi;
    if SPTSET_DEBUG_PURIFY then
      Print(">> Purify(p=", p, "): IsZeroElm(E_rf=", rf, ") = ",
            SptSetFpZModuleIsZeroElm(Epqrf, cp), " cp=", cp, "\n");
    fi;
    if not SptSetFpZModuleIsZeroElm(Epqrf, cp) then
      break;
    fi;

    #Assert(0, SptSetFpZModuleIsZeroElm(
    #SptSetSpecSeqComponent2(SS, p+1, p, q), cp),
    #"Assertion: p+1 should be the highest page with trivialization");
    for r in [p,(p-1)..2] do
      Erpq := SptSetSpecSeqComponent(SS, r, p, q);
      if SPTSET_DEBUG_PURIFY then
        Print(">> Purify(p=", p, ",r=", r, "): IsZeroElm(E_", r, ") = ",
              SptSetFpZModuleIsZeroElm(Erpq, cp), " cp=", cp, "\n");
      fi;
      if not SptSetFpZModuleIsZeroElm(Erpq, cp) then
        bdry2 := PartialPurify@(coc, p, r, cp);
        SptSetStackInplace(bdry, bdry2);
        cp_ := coc!.layers[p+1];
        cp := SptSetMapFromBarCocycle(brMap, p, SS!.spectrum[q+1], cp_);
        if SPTSET_DEBUG_PURIFY then
          Print(">> Purify(p=", p, ",r=", r, "): after kill, cp=", cp,
                " IsZeroElm(E_2)=", SptSetFpZModuleIsZeroElm(
                  SptSetSpecSeqComponent(SS, 2, p, q), cp), "\n");
        fi;
      fi;
    od;

    if SPTSET_DEBUG_PURIFY then
      Print(">> PurifyCobdry(p=", p, "): final cp=", cp, "\n");
    fi;
    bdry2 := PartialPurifyCoboundary@(coc, p, cp);
    SptSetStackInplace(bdry, bdry2);

    # If the class at layer p could not be killed by any differential or as a
    # coboundary (a genuine obstruction), stop: the leading layer is p.
    cp_ := coc!.layers[p+1];
    if cp_ <> ZeroCocycle@ then
      cp := SptSetMapFromBarCocycle(brMap, p, SS!.spectrum[q+1], cp_);
      if not SptSetFpZModuleIsZeroElm(
          SptSetSpecSeqComponent(SS, 2, p, q), cp) then
        if SPTSET_DEBUG_PURIFY then
          Print(">> Purify(p=", p, "): genuine obstruction, leading layer\n");
        fi;
        break;
      fi;
    fi;

  od;

  cl!.cochain := coc;
  SetLeadingLayer(cl, p);

  return bdry;
end);

InstallGlobalFunction(PartialConstructSSCochain@,
  function(SS, deg, p, cp, r)
    # r means the construction needed for the computation of the derivative on the r-th page (d_r).
    # i. e. the cochain contains r terms: c^p, ..., c^{p+r-2}.
    local brMap, q, coc, cp_, dc, p2, q2, r2, Erpq2, dcp2_, dcp2, cp_prime;
    brMap := SS!.brMap;
    q := deg - p;
    coc := SptSetSpecSeqCochainZero(SS, deg);

    cp_ := SptSetMapToBarCocycle(brMap, p, SS!.spectrum[q+1], cp);
    coc!.layers[p+1] := cp_;

    Assert(0, r >= 2, "PartialConstruction is only needed for r>=2.");
    if r = 2 then
      return coc;
    fi;

    dc := SptSetSpecSeqCoboundarySL(SS, deg, p, cp_);
    dc!.layers[p+1 +1] := ZeroCocycle@ ; # cp_ must be a cocycle.

    for p2 in [(p+1)..(p+r-1)] do
      q2 := deg - p2;

      dcp2_ := dc!.layers[p2+1 +1];
      dcp2 := SptSetMapFromBarCocycle(brMap, p2+1, SS!.spectrum[q2+1], dcp2_);
      if not ForAll(dcp2, IsInt) then
        Print("!! DIAG PartialConstruct(deg=",deg,",p=",p,
              ",p2=",p2,"): dcp2 FRAC\n");
      fi;

      for r2 in [(p2-p), (p2-p-1)..2] do
        Erpq2 := SptSetSpecSeqComponent(SS, r2, p2+1, q2);
        if not SptSetFpZModuleIsZeroElm(Erpq2, dcp2) then
          cp_prime := PartialPurify@(dc, p2+1, r2, dcp2);
          SptSetStackInplace(coc, cp_prime);
          dcp2_ := dc!.layers[p2+1 +1];
          dcp2 := SptSetMapFromBarCocycle(brMap, p2+1, SS!.spectrum[q2+1], dcp2_);
        fi;
      od;

      coc!.layers[p2 +1] := PartialPurifyCoboundary@(dc, p2+1, dcp2);                   
    od;

    return coc;
end);

InstallGlobalFunction(SptSetMapSpecSeqCochainByGroupHomomorphism,
function(c, ss2, f)
  local F, deg, layers;
  F := FamilyObj(c);
  deg := F!.degree;
  layers := c!.layers;

  return SptSetSpecSeqCochain(ss2, deg, List(layers,
    a -> MapInhomoCochainByGroupHomomorphism@(a, f)));
end);
        
