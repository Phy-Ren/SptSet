LoadPackage("SptSet");

for i in [2..50] do
    Display(i);
    SG := SpaceGroupBBNWZ(3, i);
    fSG := IsomorphismPcpGroup(SG);
    SG1 := Image(fSG);

    R := ResolutionAlmostCrystalGroup(SG1, 6);
    gs := GeneratorsOfGroup(SG);

    f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
        List(gs, x -> Image(fSG, x)),
        List(gs, x -> [[DeterminantMat(x)]]));

    w := Spin12Factor(3, i);
    ww := {g1, g2} -> w(PreImageElm(fSG, g1), PreImageElm(fSG, g2));


    SS := FermionSPTSpecSeq(R, f, ww);
    FermionSPTLayersVerbose(SS, 3);
od;