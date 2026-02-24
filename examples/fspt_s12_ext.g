Read("point_group_res.g");;
LoadPackage("SptSet");;
for i in [1..Length(PtGrpNames)] do
  Display(PtGrpNames[i]);;
  R := PtGrpRs[i];;
  PG := PtGrps[i];;
  gens := GeneratorsOfGroup(PG);;
  signs := List(gens, x -> [[DeterminantMat(x)]]);;
  f := GroupHomomorphismByImagesNC(PG, GL(1, Integers), gens, signs);;
  w2 := Spin12FactorForPointGroup(PG);
  ss := FermionSPTSpecSeq(R, f, w2);;
  # FermionSPTLayersVerbose(ss, 3);;
  FermionEZSPTLayersVerbose(ss, 3);;
  
  layers := FermionEZSPTLayers(ss, 3);
  Display("Layers:");
  Display(layers);

  M := SptSetSpecSeqResult(ss, 4, [2, 3, 4]);
  SptSetFpZModuleCanonicalForm(M);
  Display(M);
od;