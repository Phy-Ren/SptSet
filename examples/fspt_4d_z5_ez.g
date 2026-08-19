# 4+1D FSPT classification: G_b = Z_5, omega2 = 0, s1 = 0 (EZ case)
# G_f = Z_2^f x Z_5 (trivial extension, unitary)

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(5);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;

ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z5 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
