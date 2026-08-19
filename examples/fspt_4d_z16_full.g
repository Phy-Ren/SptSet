# 4+1D FSPT classification: G_b = Z_16, omega2 nontrivial, s1 = 0
# G_f = Z_32^f (nontrivial central extension)
# omega2(g^i, g^j) = 1 iff i+j >= 16

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(16);;
R := ResolutionFiniteGroup(G, 10);;
s1Trivial := SptSetTrivialGroupAction(G);;

f1 := GeneratorsOfGroup(G)[1];;
elts := List([0..16-1], i -> f1^i);;
exp := g -> Position(elts, g) - 1;

omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 16 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeq(R, s1Trivial, omega2);;
Print("=== Z16 non-EZ full (omega2 nontrivial, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
