# 4+1D FSPT classification: G_b = Z_4, omega2 = l2, s1 = l1 (anti-unitary)
# G_f = Z_8^{Tf}: time reversal with T^2 = P_f
# omega2(g^i, g^j) = 1 iff i+j >= 4  (standard cocycle for Z_8 -> Z_4)
# Twisted coefficients: H^2(Z4,Z^T)=0, H^5(Z4,U(1)^T)=0.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(4);;
R := ResolutionFiniteGroup(G, 10);;
f1 := GeneratorsOfGroup(G)[1];;

auMapT := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[ -1 ]]]);;

elts := [Identity(G), f1, f1^2, f1^3];;
exp := g -> Position(elts, g) - 1;

omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 4 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeq(R, auMapT, omega2);;
Print("=== Z4 anti-unitary (omega2=l2, s1=l1) ===\n");
FermionSPTLayersVerbose(ss, 4);;
