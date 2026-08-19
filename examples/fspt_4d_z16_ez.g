# 4+1D FSPT classification: G_b = Z_16, omega2 = 0, s1 = 0 (EZ case)
# G_f = Z_2^f x Z_16 (trivial extension, unitary)

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(16);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;

ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z16 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
