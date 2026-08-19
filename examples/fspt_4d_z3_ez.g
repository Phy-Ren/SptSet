# 4+1D FSPT classification: G_b = Z_3, omega2 = 0, s1 = 0
# H^2(Z_3, Z_2) = 0  (3 is odd => 3*Z_2 = Z_2, quotient is trivial)
# H^1(Z_3, Z_2) = 0  (no nontrivial hom Z_3 -> Z_2)
# So omega2 and s1 are forced trivial — only EZ is possible.
# G_f = Z_2^f x Z_3 (trivial extension)

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(3);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;

ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z3 EZ (omega2=0 forced, s1=0 forced) ===\n");
FermionSPTLayersVerbose(ss, 4);;
