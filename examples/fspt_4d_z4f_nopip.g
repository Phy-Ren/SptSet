# 4+1D FSPT classification test WITHOUT the p+ip layer.
# Symmetry: G_f = Z_4^f, so G_b = Z_2, omega2 is the non-trivial
# central extension cocycle, and s1 = 0.
# Expected cohomological layer structure for the triplet (no p+ip):
#   Majorana n3:        Z_2
#   Complex fermion n4: Z_2
#   Bosonic nu5:        Z_2
# Stacking is not tested here.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(2);;
R := ResolutionFiniteGroup(G, 8);;
utAct := SptSetTrivialGroupAction(G);;
f1 := GeneratorsOfGroup(G)[1];;

omega2 := function(g1, g2)
  if g1 = f1 and g2 = f1 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeqNoPip(R, utAct, omega2);;
FermionSPTLayersNoPipVerbose(ss, 4);;
