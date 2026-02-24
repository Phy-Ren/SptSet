LoadPackage("HAP");;
PtGrpNames := [];;
SpaceGrps := [];;
PtGrps := [];;

#PtGrpsMC := [];;
PtGrpRs := [];;

#Add(PtGrpNames, "P1");;
#Add(SpaceGrps, 1);;

Add(PtGrpNames, "C2");;
Add(SpaceGrps, 3);;
#Add(PtGrpsMC, Group([(1,2)]));;

Add(PtGrpNames, "Cs");;
Add(SpaceGrps, 6);;
#Add(PtGrpsMC, Group([(1,2)]));;

Add(PtGrpNames, "C2h");;
Add(SpaceGrps, 10);;
#Add(PtGrpsMC, Group([(1,2)]));;

Add(PtGrpNames, "D2");;
Add(SpaceGrps, 16);;
#Add(PtGrpsMC, Group([(1,2)]));;

Add(PtGrpNames, "C2v");;
Add(SpaceGrps, 25);;
#Add(PtGrpsMC, Group([(1,2), (3,4)]));;

Add(PtGrpNames, "D2h");;
Add(SpaceGrps, 47);;

Add(PtGrpNames, "C4");;
Add(SpaceGrps, 75);;

Add(PtGrpNames, "S4");;
Add(SpaceGrps, 81);;

Add(PtGrpNames, "C4h");;
Add(SpaceGrps, 83);;

Add(PtGrpNames, "D4");;
Add(SpaceGrps, 89);;

Add(PtGrpNames, "C4v");;
Add(SpaceGrps, 99);;

Add(PtGrpNames, "D2d");;
Add(SpaceGrps, 111);;

Add(PtGrpNames, "D4h");;
Add(SpaceGrps, 123);;

Add(PtGrpNames, "C3");;
Add(SpaceGrps, 143);;

Add(PtGrpNames, "S6");;
Add(SpaceGrps, 147);;

Add(PtGrpNames, "D3");;
Add(SpaceGrps, 149);;

Add(PtGrpNames, "C3v");;
Add(SpaceGrps, 156);;

Add(PtGrpNames, "D3d");;
Add(SpaceGrps, 162);;

Add(PtGrpNames, "C6");;
Add(SpaceGrps, 168);;

Add(PtGrpNames, "C3h");;
Add(SpaceGrps, 174);;

Add(PtGrpNames, "C6h");;
Add(SpaceGrps, 175);;

Add(PtGrpNames, "D6");;
Add(SpaceGrps, 177);;

Add(PtGrpNames, "C6v");;
Add(SpaceGrps, 183);;

Add(PtGrpNames, "D3h");;
Add(SpaceGrps, 187);;

Add(PtGrpNames, "D6h");;
Add(SpaceGrps, 191);;

Add(PtGrpNames, "T");;
Add(SpaceGrps, 195);;

Add(PtGrpNames, "Th");;
Add(SpaceGrps, 200);;

Add(PtGrpNames, "O");;
Add(SpaceGrps, 207);;

Add(PtGrpNames, "Td");;
Add(SpaceGrps, 215);;

Add(PtGrpNames, "Oh");;
Add(SpaceGrps, 221);;

for sg in SpaceGrps do
    Add(PtGrps, PointGroup(SpaceGroupBBNWZ(3, sg)));
od;

for i in [1..Length(PtGrpNames)] do
    Display(PtGrpNames[i]);;
    #if PtGrpNames[i] = "O" then
    #    Add(PtGrpRs, fail);;
    if PtGrpNames[i] = "D4h" then
        D4h := DirectProduct(DihedralGroup(8), Group([(1,2)]));;
        f := IsomorphismGroups(D4h, PtGrps[i]);;
        R := ResolutionFiniteGroup(D4h, 7);;
        R!.group := PtGrps[i];;
        R!.elts:=List(R!.elts, x->Image(f, x));;
        Add(PtGrpRs, R);;
    elif PtGrpNames[i] = "Oh" then
        Oh := DirectProduct(SymmetricGroup(4), Group([(1,2)]));;
        f := IsomorphismGroups(Oh, PtGrps[i]);;
        R := ResolutionFiniteGroup(Oh, 7);;
        R!.group := PtGrps[i];;
        R!.elts:=List(R!.elts, x->Image(f, x));;
        Add(PtGrpRs, R);;
    else
        Add(PtGrpRs, ResolutionFiniteGroup(PtGrps[i], 7));;
    fi;
od;