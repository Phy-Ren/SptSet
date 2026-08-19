# 4+1D FSPT: G_b = Z_64, omega2 nontrivial, s1 = 0, G_f = Z_128^f
LoadPackage("HAP");
LoadPackage("SptSet");
G := CyclicGroup(64);;
R := ResolutionFiniteGroup(G, 10);;
s1Trivial := SptSetTrivialGroupAction(G);;
f1 := GeneratorsOfGroup(G)[1];;
elts := List([0..64-1], i -> f1^i);;
exp := g -> Position(elts, g) - 1;
omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 64 then return 1; fi;
  return 0;
end;;
ss := FermionSPTSpecSeq(R, s1Trivial, omega2);;
Print("=== Z64 non-EZ full (omega2 nontrivial, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
