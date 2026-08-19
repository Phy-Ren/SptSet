# 4+1D FSPT: G_b = Z_32, omega2 = 0, s1 = 0 (EZ)
LoadPackage("HAP");
LoadPackage("SptSet");
G := CyclicGroup(32);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;
ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z32 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
