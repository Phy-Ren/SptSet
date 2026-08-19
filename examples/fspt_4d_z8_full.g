# 4+1D FSPT classification: G_b = Z_8, omega2 nontrivial, s1 = 0
# G_f = Z_16^f (nontrivial central extension 1 -> Z_2^f -> Z_16 -> Z_8 -> 1)
# omega2(g^i, g^j) = 1 iff i+j >= 8  (standard cocycle for Z_16 -> Z_8)

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(8);;
R := ResolutionFiniteGroup(G, 10);;
s1Trivial := SptSetTrivialGroupAction(G);;

f1 := GeneratorsOfGroup(G)[1];;
elts := List([0..7], i -> f1^i);;
exp := g -> Position(elts, g) - 1;

omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 8 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeq(R, s1Trivial, omega2);;
Print("=== Z8 non-EZ full (omega2 nontrivial, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
