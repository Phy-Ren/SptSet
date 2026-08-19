# 4+1D FSPT classification: G_b = Z_4, omega2 nontrivial, s1 = 0
# G_f = Z_8 (nontrivial central extension: 1 -> Z_2^f -> Z_8 -> Z_4 -> 1)
# omega2(g^i, g^j) = 1 iff i+j >= 4  (standard 2-cocycle for Z_8 extension)
# Expected: full quadruplet classification should complete without errors

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(4);;
R := ResolutionFiniteGroup(G, 10);;
s1Trivial := SptSetTrivialGroupAction(G);;

# Map group elements to exponents 0,1,2,3
f1 := GeneratorsOfGroup(G)[1];;
elts := [Identity(G), f1, f1^2, f1^3];;
exp := g -> Position(elts, g) - 1;

# Non-trivial omega2: standard cocycle for Z_8 -> Z_4 extension
omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 4 then
    return 1;
  fi;
  return 0;
end;;

# Full non-EZ constructor
ss := FermionSPTSpecSeq(R, s1Trivial, omega2);;
Print("=== Z4 non-EZ full (omega2 nontrivial, s1=0) ===\n");
FermionSPTLayersVerbose(ss, 4);;
