# 4+1D FSPT classification: G_b = Z_8, omega2 = 0, s1 nontrivial (anti-unitary)
# G_f = Z_8^T x Z_2^f with T^2 = 1
# Twisted coefficients: H^2(Z8,Z^T)=0, H^5(Z8,U(1)^T)=0.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(8);;
R := ResolutionFiniteGroup(G, 10);;
f1 := GeneratorsOfGroup(G)[1];;

auMapT := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[ -1 ]]]);;

ss := FermionEZSPTSpecSeq(R, auMapT);;
Print("=== Z8 anti-unitary (omega2=0, s1=m1) ===\n");
FermionSPTLayersVerbose(ss, 4);;
