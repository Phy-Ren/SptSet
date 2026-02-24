Read("point_group_res.g");;
LoadPackage("SptSet");;

# Test the new layer-wise SptSetSpecSeqResult on previously failing examples.
# Compare with old method where possible.

testIndices := [2, 3, 8, 11, 17];;
testNames := ["Cs", "C2h", "S4", "C4v", "C3v"];;

for idx in [1..Length(testIndices)] do
  i := testIndices[idx];;
  Display("============================================================");;
  Display(Concatenation(testNames[idx], " (index ", String(i), ")"));;
  Display("============================================================");;

  R := PtGrpRs[i];;
  PG := PtGrps[i];;
  gens := GeneratorsOfGroup(PG);;
  signs := List(gens, x -> [[DeterminantMat(x)]]);;
  f := GroupHomomorphismByImagesNC(PG, GL(1, Integers), gens, signs);;
  w2 := Spin12FactorForPointGroup(PG);;
  ss := FermionSPTSpecSeq(R, f, w2);;

  # Classification (layers) - with p+ip
  FermionSPTLayersVerbose(ss, 3);;
  layers := FermionSPTLayers(ss, 3);;
  Display("Layers [p+ip, MC, CF, Bos]:");;
  Display(layers);;

  # New method: without p+ip
  Display("--- New method [2,3,4] ---");;
  res1 := CALL_WITH_CATCH(function()
    local M;
    M := SptSetSpecSeqResult(ss, 4, [2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
    Display(M);;
  end, []);;
  if res1[1] = false then
    Display("*** FAILED ***");;
    Display(res1[2]);;
  fi;

  # New method: with p+ip
  Display("--- New method [1,2,3,4] ---");;
  res2 := CALL_WITH_CATCH(function()
    local M;
    M := SptSetSpecSeqResult(ss, 4, [1,2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
    Display(M);;
  end, []);;
  if res2[1] = false then
    Display("*** FAILED ***");;
    Display(res2[2]);;
  fi;

  # Old method for comparison: without p+ip
  Display("--- Old method [2,3,4] ---");;
  res3 := CALL_WITH_CATCH(function()
    local M;
    M := SptSetSpecSeqResultOld(ss, 4, [2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
    Display(M);;
  end, []);;
  if res3[1] = false then
    Display("*** FAILED ***");;
    Display(res3[2]);;
  fi;

  Display("");;
od;
