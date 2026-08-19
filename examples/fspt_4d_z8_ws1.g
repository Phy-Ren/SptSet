# 4+1D FSPT classification: G_b = Z_8, omega2 nontrivial, s1 nontrivial
# G_f = Z_16^{Tf}: time reversal with T^2 = P_f
# omega2(g^i, g^j) = 1 iff i+j >= 8;  generator acts anti-unitarily.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(8);;
R := ResolutionFiniteGroup(G, 10);;
f1 := GeneratorsOfGroup(G)[1];;

auMapT := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[ -1 ]]]);;

elts := List([0..7], i -> f1^i);;
exp := g -> Position(elts, g) - 1;

omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 8 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeq(R, auMapT, omega2);;
Print("=== Z8 anti-unitary (omega2=m2, s1=m1) ===\n");
FermionSPTLayersVerbose(ss, 4);;
