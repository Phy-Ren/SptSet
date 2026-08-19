# 4+1D FSPT classification: G_b = Z_4, omega2 = 0, s1 = l1 (anti-unitary)
# G_f = Z_4^T x Z_2^f with T^2 = 1
# Twisted coefficients: H^2(Z4,Z^T)=0, H^5(Z4,U(1)^T)=0.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(4);;
R := ResolutionFiniteGroup(G, 10);;
f1 := GeneratorsOfGroup(G)[1];;

# s1 = l1: generator acts anti-unitarily
auMapT := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[ -1 ]]]);;

ss := FermionEZSPTSpecSeq(R, auMapT);;
Print("=== Z4 anti-unitary (omega2=0, s1=l1) ===\n");
FermionSPTLayersVerbose(ss, 4);;
