# 4+1D FSPT classification: G_b = Z_2, omega2 = 0, s1 = 0 (EZ case)
# G_f = Z_2^f x Z_2 (trivial extension, unitary)
# H^2(Z2,Z)=Z2, H^3(Z2,Z2)=Z2, H^4(Z2,Z2)=Z2, H^5(Z2,U(1))=Z2 at E2;
# obstructions may reduce layers: dn3 = n2 cup n2 (mod 2), etc.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(2);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;

ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Z2 EZ (omega2=0, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
