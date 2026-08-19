# 4+1D FSPT: G_b = Z_64, omega2 = 0, s1 = 0 (EZ)
LoadPackage("HAP");
LoadPackage("SptSet");
G := CyclicGroup(64);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;
ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z64 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
