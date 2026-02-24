LoadPackage("SptSet");
Read("res_space_group.g");

for i in [1..230] do
    Display(i);
    SG := SpaceGroupBBNWZ(3, i);
    fSG := IsomorphismPcpGroup(SG);
    SG1 := Image(fSG);

    # R := ResolutionAlmostCrystalGroup(SG1, 6);
    R := Resolution3DSpaceGroup(fSG, 7);
    Display(R!.dimension(6));
    gs := GeneratorsOfGroup(SG);

    f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
        List(gs, x -> Image(fSG, x)),
        List(gs, x -> [[DeterminantMat(x)]]));

    SS := FermionEZSPTSpecSeq(R, f);
    FermionSPTLayersVerbose(SS, 3);
od;