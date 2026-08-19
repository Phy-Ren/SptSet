# 4+1D FSPT classification: G_b = Z_4, omega2 = 0, s1 = 0 (EZ case)
# G_f = Z_2^f x Z_4 (trivial extension)
# Expected: classification should complete without errors

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(4);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;

# EZ constructor: omega2 = 0 built-in
ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z4 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
