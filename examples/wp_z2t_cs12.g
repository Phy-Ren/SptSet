LoadPackage("SptSet");

for it in [2..17] do
  Display(it);
  SG := SpaceGroupBBNWZ(2, it);
  Z2T := CyclicGroup(2);
  fSG := IsomorphismPcpGroup(SG);
  SG1 := Image(fSG);
  gs := GeneratorsOfGroup(SG);
  # G := DirectProduct(SG1, Z2T);
  Rs := ResolutionAlmostCrystalGroup(SG1, 6);
  Rt := ResolutionFiniteGroup(Z2T, 6);
  R := ResolutionDirectProduct(Rs, Rt);
  G := GroupOfResolution(R);
  Ps := Projection(G, 1);
  Pt := Projection(G, 2);
  trs := GeneratorsOfGroup(Z2T)[1];
  fs := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
    List(gs, x -> Image(fSG, x)),
    List(gs, x -> [[DeterminantMat(x)]]));
  f := GroupHomomorphismByFunction(G, GL(1, Integers), function(g)
    local gs, gt;
    gs := g ^ Ps;
    gt := g ^ Pt;
    if gt = trs then
      return -gs^fs;
    else
      return gs^fs;
    fi;
  end);

  w := function(g1, g2)
    # local sg1, sg2, t1, t2, wt, wgt;
    local t1;
    # sg1 := Projection(g1, 1);
    # sg2 := Projection(g2, 1);
    # t1 := Projection(g1, 2);
    # t2 := g2^Pt;
    # if t2 = trs then
    #   return (1 - (g1^f)[1][1])/2;
    # else
    #   return 0;
    # fi;
    t1 := g1^Pt;
    if t1 = trs then
      return (1 - (g2^f)[1][1])/2;
    else
      return 0;
    fi;
  end;

  #SS := FermionEZSPTSpecSeq(R, f: BarResMapChoice := "HAP");
  #SS := FermionEZSPTSpecSeq(R, f: BarResMapChoice := "debug");
  SS := FermionSPTSpecSeq(R, f, w);
  FermionSPTLayersVerbose(SS, 2);
  layers := FermionSPTLayers(SS, 2);
  Display("Layers:");
  Display(layers);

  M := SptSetSpecSeqResult(SS, 3, [1,2,3]);
  SptSetFpZModuleCanonicalForm(M);
  Display(M);
  
od;