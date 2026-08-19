# 4+1D FSPT: G_b = Z_32, omega2 nontrivial, s1 = 0, G_f = Z_64^f
LoadPackage("HAP");
LoadPackage("SptSet");
G := CyclicGroup(32);;
R := ResolutionFiniteGroup(G, 10);;
s1Trivial := SptSetTrivialGroupAction(G);;
f1 := GeneratorsOfGroup(G)[1];;
elts := List([0..32-1], i -> f1^i);;
exp := g -> Position(elts, g) - 1;
omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 32 then return 1; fi;
  return 0;
end;;
ss := FermionSPTSpecSeq(R, s1Trivial, omega2);;
Print("=== Z32 non-EZ full (omega2 nontrivial, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
