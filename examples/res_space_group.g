BindGlobal("Resolution3DSpaceGroup", function(sg_pcp_iso, nTerms)
    local SG, SG1, fSGPG, Z31, RZ31, fSGPG1, PG1, PGid, PG2, fPG21, RPG1;
    SG := Source(sg_pcp_iso);
    SG1 := Image(sg_pcp_iso);
    fSGPG := PointHomomorphism(SG);
    Z31 := Image(sg_pcp_iso, Kernel(fSGPG));

    RZ31 := ResolutionAlmostCrystalGroup(Z31, nTerms);
    fSGPG1 := NaturalHomomorphismByNormalSubgroup( SG1, Z31 );
    PG1 := ImagesSource(fSGPG1);
    PGid := IdGroup(PG1);
    if PGid = [16, 11] then
        PG2 := DirectProduct(DihedralGroup(8), Group([(1,2)]));
    fi;
    if PGid = [24, 12] then
        PG2 := SymmetricGroup(4);
    fi;
    if PGid = [48, 48] then
        PG2 := DirectProduct(SymmetricGroup(4), Group([(1,2)]));
    fi;
    if IsBound(PG2) then
        fPG21 := IsomorphismGroups(PG2, PG1);
        RPG1 := ResolutionFiniteGroup(PG2, nTerms);
        RPG1!.group := PG1;
        RPG1!.elts := List(RPG1!.elts, x -> Image(fPG21, x));
    else
        RPG1 := ResolutionFiniteGroup(PG1, nTerms);
    fi;

    return ResolutionExtension(fSGPG1, RZ31, RPG1);
end);