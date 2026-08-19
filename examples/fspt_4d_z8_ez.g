# 4+1D FSPT classification: G_b = Z_8, omega2 = 0, s1 = 0 (EZ case)
# G_f = Z_2^f x Z_8 (trivial extension, unitary)
# H^2(Z8,Z)=Z8, H^3(Z8,Z2)=Z2, H^4(Z8,Z2)=Z2, H^5(Z8,U(1))=Z8 at E2.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(8);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;

ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z8 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
